import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';

import 'cloud_service.dart';
import 'location_service.dart';
import 'sos_message.dart';

const _serviceId = 'com.nosignal.sos';

/// P2P_CLUSTER lets every phone connect to many others at once (a mesh).
const _strategy = Strategy.P2P_CLUSTER;

/// The heart of the app: finds nearby phones, stores every SOS it hears,
/// passes it on to every neighbour, and uploads it if this phone has internet.
///
/// Two kinds of packets travel through the mesh:
///   {type: 'sos', data: {...}}  - an emergency message
///   {type: 'ack', id: '...'}    - "the rescue team has received message <id>"
class MeshService extends ChangeNotifier {
  MeshService({
    required this.deviceName,
    this.allowedPeers = const {},
    this.forceOffline = false,
  });

  final String deviceName;

  /// Demo option: if not empty, only connect to phones with these names.
  /// Lets us force a chain A -> B -> C on a small stage where all phones are in range.
  final Set<String> allowedPeers;

  /// Demo option: never upload, even if this phone has internet.
  final bool forceOffline;

  final _cloud = CloudService();

  /// Connected neighbours: endpointId -> phone name.
  final Map<String, String> peers = {};

  /// Every SOS this phone has seen, by message id.
  final Map<String, SosMessage> messages = {};

  final Set<String> _connecting = {};
  final Map<String, String> _connectingNames = {};
  final Set<String> _acked = {};
  Timer? _cloudTimer;
  bool _uploading = false;

  bool online = false;
  String status = 'Starting…';

  List<SosMessage> get sortedMessages =>
      messages.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Future<void> start() async {
    try {
      await Nearby().startAdvertising(
        deviceName,
        _strategy,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
        serviceId: _serviceId,
      );
      await Nearby().startDiscovery(
        deviceName,
        _strategy,
        onEndpointFound: (id, name, serviceId) => _onEndpointFound(id, name),
        onEndpointLost: (id) {},
        serviceId: _serviceId,
      );
      _setStatus('Searching for nearby phones…');
    } catch (e) {
      _setStatus('Could not start mesh: $e');
    }
    _cloudTimer = Timer.periodic(const Duration(seconds: 5), (_) => _syncWithCloud());
    _syncWithCloud();
  }

  Future<void> stop() async {
    _cloudTimer?.cancel();
    await Nearby().stopAdvertising();
    await Nearby().stopDiscovery();
    await Nearby().stopAllEndpoints();
  }

  /// Called when the user presses the SOS button.
  Future<SosMessage> sendSos({
    required String text,
    required int people,
    required List<String> tags,
  }) async {
    final pos = await currentLocation();
    final now = DateTime.now().millisecondsSinceEpoch;
    final sos = SosMessage(
      id: '$now${Random().nextInt(1 << 30)}',
      sender: deviceName,
      text: text,
      people: people,
      tags: tags,
      lat: pos?.latitude,
      lng: pos?.longitude,
      createdAt: now,
      path: [deviceName],
    );
    messages[sos.id] = sos;
    _broadcast({'type': 'sos', 'data': sos.toJson()});
    notifyListeners();
    _syncWithCloud();
    return sos;
  }

  // ---------------------------------------------------------------- discovery

  bool _isAllowed(String name) => allowedPeers.isEmpty || allowedPeers.contains(name);

  void _onEndpointFound(String id, String name) {
    if (!_isAllowed(name) || peers.containsKey(id) || _connecting.contains(id)) return;
    // Both phones discover each other. Only the one with the alphabetically smaller
    // name dials, so they don't both dial at once and collide.
    if (deviceName.compareTo(name) < 0) {
      _requestConnection(id);
    } else {
      // Fallback in case the other phone never dials us.
      Future.delayed(const Duration(seconds: 6), () {
        if (!peers.containsKey(id) && !_connecting.contains(id)) _requestConnection(id);
      });
    }
  }

  Future<void> _requestConnection(String id) async {
    _connecting.add(id);
    try {
      await Nearby().requestConnection(
        deviceName,
        id,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
    } catch (_) {
      _connecting.remove(id);
    }
  }

  void _onConnectionInitiated(String id, ConnectionInfo info) {
    if (!_isAllowed(info.endpointName)) {
      Nearby().rejectConnection(id);
      return;
    }
    _connecting.add(id);
    _connectingNames[id] = info.endpointName;
    // Both sides must accept. No PIN check: in a disaster, any phone may relay.
    Nearby().acceptConnection(
      id,
      onPayLoadRecieved: (endpointId, payload) {
        if (payload.type == PayloadType.BYTES && payload.bytes != null) {
          _onPacket(endpointId, utf8.decode(payload.bytes!));
        }
      },
    );
  }

  void _onConnectionResult(String id, Status result) {
    _connecting.remove(id);
    final name = _connectingNames.remove(id) ?? id;
    if (result == Status.CONNECTED) {
      peers[id] = name;
      _setStatus('Connected to ${peers.length} phone(s)');
      // Store-and-forward: a phone that arrives late still gets every SOS we know.
      for (final m in messages.values) {
        _send(id, {'type': 'sos', 'data': m.toJson()});
      }
      for (final ackId in _acked) {
        _send(id, {'type': 'ack', 'id': ackId});
      }
    }
    notifyListeners();
  }

  void _onDisconnected(String id) {
    peers.remove(id);
    _connecting.remove(id);
    _setStatus(peers.isEmpty ? 'Searching for nearby phones…' : 'Connected to ${peers.length} phone(s)');
  }

  // ---------------------------------------------------------------- relaying

  void _onPacket(String fromId, String raw) {
    final Map<String, dynamic> packet;
    try {
      packet = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    if (packet['type'] == 'sos') {
      final incoming = SosMessage.fromJson(packet['data'] as Map<String, dynamic>);
      if (messages.containsKey(incoming.id)) return; // already seen: stops infinite loops
      final mine = incoming.relayedBy(deviceName);
      mine.delivered = _acked.contains(mine.id);
      messages[mine.id] = mine;
      _broadcast({'type': 'sos', 'data': mine.toJson()}, except: fromId);
      notifyListeners();
      _syncWithCloud();
    } else if (packet['type'] == 'ack') {
      _onAck(packet['id'] as String, except: fromId);
    }
  }

  /// Spreads "rescue team received it" back through the mesh, so the person
  /// who sent the SOS sees a confirmation even though they have no internet.
  void _onAck(String id, {String? except}) {
    if (!_acked.add(id)) return;
    messages[id]?.delivered = true;
    _broadcast({'type': 'ack', 'id': id}, except: except);
    notifyListeners();
  }

  void _broadcast(Map<String, dynamic> packet, {String? except}) {
    for (final id in peers.keys) {
      if (id != except) _send(id, packet);
    }
  }

  Future<void> _send(String endpointId, Map<String, dynamic> packet) async {
    try {
      await Nearby().sendBytesPayload(
        endpointId,
        Uint8List.fromList(utf8.encode(jsonEncode(packet))),
      );
    } catch (_) {
      // Neighbour probably walked out of range; they'll get it on reconnect.
    }
  }

  // ---------------------------------------------------------------- cloud

  Future<void> _syncWithCloud() async {
    if (_uploading || forceOffline || !_cloud.configured) {
      if (online) {
        online = false;
        notifyListeners();
      }
      return;
    }
    _uploading = true;
    try {
      final pending = messages.values.where((m) => !m.delivered).toList();
      if (pending.isEmpty) {
        _setOnline(await _cloud.ping());
        return;
      }
      for (final m in pending) {
        final ok = await _cloud.upload(m, uploadedBy: deviceName);
        _setOnline(ok);
        if (!ok) break;
        _onAck(m.id);
      }
    } finally {
      _uploading = false;
    }
  }

  void _setOnline(bool value) {
    if (online == value) return;
    online = value;
    notifyListeners();
  }

  void _setStatus(String s) {
    status = s;
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

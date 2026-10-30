import 'dart:math';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'mesh_service.dart';
import 'sos_message.dart';

void main() => runApp(const NoSignalApp());

const _sosRed = Color(0xFFE53935);
const _quickTags = ['Injured', 'Trapped', 'Medical emergency', 'Fire', 'Need water', 'Need food'];

class NoSignalApp extends StatelessWidget {
  const NoSignalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NoSignal SOS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: _sosRed,
        brightness: Brightness.dark,
      ),
      home: const StartScreen(),
    );
  }
}

/// Bluetooth, Wi-Fi Direct and location permissions needed by Nearby Connections.
Future<bool> requestMeshPermissions() async {
  final results = await [
    Permission.location,
    Permission.bluetooth,
    Permission.bluetoothAdvertise,
    Permission.bluetoothConnect,
    Permission.bluetoothScan,
    Permission.nearbyWifiDevices,
  ].request();
  return results[Permission.location]?.isGranted ?? false;
}

// ============================================================== start screen

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  final _name = TextEditingController(text: 'Phone-${Random().nextInt(900) + 100}');
  final _allowed = TextEditingController();
  bool _forceOffline = false;
  bool _busy = false;
  String? _error;

  Future<void> _start() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    if (!await requestMeshPermissions()) {
      setState(() {
        _busy = false;
        _error = 'Location and Nearby devices permissions are needed to find other phones.';
      });
      return;
    }
    final mesh = MeshService(
      deviceName: name,
      allowedPeers: _allowed.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet(),
      forceOffline: _forceOffline,
    );
    await mesh.start();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => HomeScreen(mesh: mesh)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 32),
            const Icon(Icons.cell_tower, size: 72, color: _sosRed),
            const SizedBox(height: 12),
            Text('NoSignal SOS',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Emergency messages that hop from phone to phone\nwhen there is no network.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'This phone\'s name',
                helperText: 'Must be different on every phone',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ExpansionTile(
              title: const Text('Demo settings'),
              childrenPadding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                TextField(
                  controller: _allowed,
                  decoration: const InputDecoration(
                    labelText: 'Only connect to (optional)',
                    helperText: 'Comma-separated names, e.g. Phone-B. Forces a chain on stage.',
                    border: OutlineInputBorder(),
                  ),
                ),
                SwitchListTile(
                  value: _forceOffline,
                  onChanged: (v) => setState(() => _forceOffline = v),
                  title: const Text('Act as if this phone has no internet'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
            ],
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _busy ? null : _start,
              icon: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.wifi_tethering),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('Join the mesh', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================== home screen

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.mesh});

  final MeshService mesh;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  MeshService get mesh => widget.mesh;

  @override
  void dispose() {
    mesh.dispose();
    super.dispose();
  }

  Future<void> _openSosSheet() async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SosSheet(mesh: mesh),
    );
    if (sent == true && mounted) {
      final n = mesh.peers.length;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(n == 0
            ? 'SOS saved. It will be sent as soon as a phone comes in range.'
            : 'SOS sent to $n nearby phone(s).'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: mesh,
      builder: (context, _) {
        final messages = mesh.sortedMessages;
        return Scaffold(
          appBar: AppBar(
            title: Text(mesh.deviceName),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Row(children: [
                  Icon(mesh.online ? Icons.cloud_done : Icons.cloud_off,
                      color: mesh.online ? Colors.greenAccent : Colors.grey),
                  const SizedBox(width: 6),
                  Text(mesh.online ? 'Online' : 'No internet'),
                ]),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _MeshStatusCard(mesh: mesh),
              const SizedBox(height: 24),
              Center(child: _SosButton(onPressed: _openSosSheet)),
              const SizedBox(height: 28),
              Text('Messages in the mesh (${messages.length})',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (messages.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No SOS messages yet.', textAlign: TextAlign.center),
                ),
              for (final m in messages) _MessageTile(message: m, isMine: m.sender == mesh.deviceName),
            ],
          ),
        );
      },
    );
  }
}

class _MeshStatusCard extends StatelessWidget {
  const _MeshStatusCard({required this.mesh});

  final MeshService mesh;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.hub),
              const SizedBox(width: 8),
              Expanded(child: Text(mesh.status)),
            ]),
            if (mesh.peers.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final name in mesh.peers.values)
                    Chip(avatar: const Icon(Icons.smartphone, size: 18), label: Text(name)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SosButton extends StatelessWidget {
  const _SosButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 180,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          shape: const CircleBorder(),
          backgroundColor: _sosRed,
          foregroundColor: Colors.white,
          elevation: 12,
        ),
        child: const Text('SOS', style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({required this.message, required this.isMine});

  final SosMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final m = message;
    final time = DateTime.fromMillisecondsSinceEpoch(m.createdAt);
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return Card(
      color: isMine ? _sosRed.withValues(alpha: 0.18) : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(isMine ? 'Your SOS' : 'From ${m.sender}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              Text('$hh:$mm'),
            ]),
            const SizedBox(height: 6),
            if (m.tags.isNotEmpty || m.people > 1)
              Text([...m.tags, '${m.people} ${m.people == 1 ? 'person' : 'people'}'].join(' · ')),
            if (m.text.isNotEmpty) Text('"${m.text}"'),
            const SizedBox(height: 6),
            Text('Route: ${m.path.join(' → ')}  (${m.hops} hop${m.hops == 1 ? '' : 's'})',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Row(children: [
              Icon(m.delivered ? Icons.verified : Icons.sync,
                  size: 18, color: m.delivered ? Colors.greenAccent : Colors.amber),
              const SizedBox(width: 6),
              Text(m.delivered ? 'Rescue team notified' : 'Spreading through the mesh…',
                  style: TextStyle(color: m.delivered ? Colors.greenAccent : Colors.amber)),
            ]),
          ],
        ),
      ),
    );
  }
}

// ============================================================== SOS sheet

class SosSheet extends StatefulWidget {
  const SosSheet({super.key, required this.mesh});

  final MeshService mesh;

  @override
  State<SosSheet> createState() => _SosSheetState();
}

class _SosSheetState extends State<SosSheet> {
  final _text = TextEditingController();
  final Set<String> _tags = {};
  int _people = 1;
  bool _sending = false;

  Future<void> _send() async {
    setState(() => _sending = true);
    await widget.mesh.sendSos(text: _text.text.trim(), people: _people, tags: _tags.toList());
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Send SOS', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in _quickTags)
                FilterChip(
                  label: Text(tag),
                  selected: _tags.contains(tag),
                  onSelected: (on) => setState(() => on ? _tags.add(tag) : _tags.remove(tag)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(children: [
            const Text('People with you:'),
            const Spacer(),
            IconButton(
              onPressed: _people > 1 ? () => setState(() => _people--) : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text('$_people', style: const TextStyle(fontSize: 18)),
            IconButton(
              onPressed: () => setState(() => _people++),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ]),
          TextField(
            controller: _text,
            maxLength: 140,
            decoration: const InputDecoration(
              labelText: 'Short message (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _sending ? null : _send,
            style: FilledButton.styleFrom(backgroundColor: _sosRed, foregroundColor: Colors.white),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(_sending ? 'Getting location…' : 'SEND SOS', style: const TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }
}

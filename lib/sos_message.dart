/// One emergency message travelling through the mesh.
class SosMessage {
  SosMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.people,
    required this.tags,
    required this.lat,
    required this.lng,
    required this.createdAt,
    required this.path,
    this.delivered = false,
  });

  /// Unique ID, so phones can ignore messages they have already seen.
  final String id;
  final String sender;
  final String text;
  final int people;
  final List<String> tags;
  final double? lat;
  final double? lng;

  /// Milliseconds since epoch, set by the sender.
  final int createdAt;

  /// Every phone the message passed through, starting with the sender.
  final List<String> path;

  /// Local only: true once the rescue dashboard has received this message.
  bool delivered;

  int get hops => path.length - 1;

  /// The copy this phone stores and forwards: same message, one more hop.
  SosMessage relayedBy(String deviceName) => SosMessage(
        id: id,
        sender: sender,
        text: text,
        people: people,
        tags: tags,
        lat: lat,
        lng: lng,
        createdAt: createdAt,
        path: [...path, deviceName],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender': sender,
        'text': text,
        'people': people,
        'tags': tags,
        'lat': lat,
        'lng': lng,
        'createdAt': createdAt,
        'path': path,
      };

  factory SosMessage.fromJson(Map<String, dynamic> j) => SosMessage(
        id: j['id'] as String,
        sender: j['sender'] as String,
        text: (j['text'] ?? '') as String,
        people: (j['people'] ?? 1) as int,
        tags: List<String>.from(j['tags'] ?? const []),
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        createdAt: j['createdAt'] as int,
        path: List<String>.from(j['path'] ?? const []),
      );
}

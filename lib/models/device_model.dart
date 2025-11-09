/// Device model for discovered devices
/// TODO: Add more device properties as needed
class DeviceModel {
  final String id;
  final String name;
  final String type; // 'wifi_aware', 'ble', 'network'
  final bool isConnected;
  final DateTime discoveredAt;
  final Map<String, dynamic> metadata;

  const DeviceModel({
    required this.id,
    required this.name,
    required this.type,
    this.isConnected = false,
    required this.discoveredAt,
    this.metadata = const {},
  });

  /// Create a copy with updated properties
  DeviceModel copyWith({
    String? id,
    String? name,
    String? type,
    bool? isConnected,
    DateTime? discoveredAt,
    Map<String, dynamic>? metadata,
  }) {
    return DeviceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      isConnected: isConnected ?? this.isConnected,
      discoveredAt: discoveredAt ?? this.discoveredAt,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'isConnected': isConnected,
      'discoveredAt': discoveredAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  /// Create from JSON
  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      isConnected: json['isConnected'] as bool? ?? false,
      discoveredAt: DateTime.parse(json['discoveredAt'] as String),
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeviceModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'DeviceModel(id: $id, name: $name, type: $type, isConnected: $isConnected)';
  }
}

/// A named set of options that a spin wheel picks from.
class Wheel {
  final String id;
  final String name;
  final List<String> options;

  Wheel({required this.id, required this.name, this.options = const []});

  /// Lenient on purpose: one malformed record must not blank the whole tab.
  factory Wheel.fromJson(Map<String, dynamic> json) => Wheel(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        options: (json['options'] as List? ?? const [])
            .map((e) => e.toString())
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'options': options,
      };
}

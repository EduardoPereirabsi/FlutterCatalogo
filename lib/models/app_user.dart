/// Usuario da sessao (RF07).
///
/// A mesma classe representa tanto o usuario do login local (baseline) quanto
/// o usuario autenticado no Supabase (bonus). A flag [isCloud] diz de onde ele
/// veio, e e ela que a UI usa para mostrar o selo "sincronizado".
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.isCloud,
  });

  final String id;
  final String email;
  final String displayName;
  final bool isCloud;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'email': email,
        'displayName': displayName,
        'isCloud': isCloud,
      };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: (json['id'] ?? '').toString(),
        email: (json['email'] ?? '').toString(),
        displayName: (json['displayName'] ?? '').toString(),
        isCloud: json['isCloud'] == true,
      );

  @override
  bool operator ==(Object other) => other is AppUser && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

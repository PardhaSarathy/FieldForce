import '../enums/app_enums.dart';

/// Geographic hierarchy: Territory > Area > Cluster (§68).
class Territory {
  const Territory({
    required this.id,
    required this.name,
    required this.headquarters,
    this.areaIds = const [],
  });

  final String id;
  final String name;
  final String headquarters;
  final List<String> areaIds;
}

class Area {
  const Area({
    required this.id,
    required this.name,
    required this.territoryId,
    this.clusterIds = const [],
  });

  final String id;
  final String name;
  final String territoryId;
  final List<String> clusterIds;
}

class Cluster {
  const Cluster({required this.id, required this.name, required this.areaId});

  final String id;
  final String name;
  final String areaId;
}

/// A person in the organization.
///
/// [managerId] forms the reporting tree that [DataScope] walks; a null manager
/// means the top of the hierarchy.
class Employee {
  const Employee({
    required this.id,
    required this.employeeCode,
    required this.name,
    required this.role,
    required this.designation,
    required this.mobile,
    required this.email,
    required this.territoryId,
    required this.territoryName,
    required this.headquarters,
    this.managerId,
    this.managerName,
    this.areaId,
    this.areaName,
    this.clusterId,
    this.clusterName,
    this.department = 'Sales & Marketing',
    this.photoUrl,
    this.joiningDate,
    this.bloodGroup,
    this.isActive = true,
    this.lastKnownLatitude,
    this.lastKnownLongitude,
    this.lastSeenAt,
  });

  final String id;
  final String employeeCode;
  final String name;
  final UserRole role;
  final String designation;
  final String mobile;
  final String email;
  final String territoryId;
  final String territoryName;
  final String headquarters;
  final String? managerId;
  final String? managerName;
  final String? areaId;
  final String? areaName;
  final String? clusterId;
  final String? clusterName;
  final String department;
  final String? photoUrl;
  final DateTime? joiningDate;
  final String? bloodGroup;
  final bool isActive;

  /// Last reported position, used by the team map (§42). Null until the
  /// employee records an activity with location.
  final double? lastKnownLatitude;
  final double? lastKnownLongitude;
  final DateTime? lastSeenAt;

  DataScope get scope => DataScope.forRole(role);

  /// Display line used under the name throughout the app.
  String get subtitle => '$designation · $headquarters';
}

/// Immutable snapshot of who is signed in and what they may see.
class Session {
  const Session({
    required this.employee,
    required this.loginAt,
    this.token = 'mock-session-token',
    this.disabledModules = const {},
    this.mustChangePassword = false,
    this.geoFencePolicy = GeoFencePolicy.warn,
    this.geoFenceRadiusMeters = 50,
    this.billRequiredAbove,
  });

  final Employee employee;
  final DateTime loginAt;
  final String token;

  /// Modules the organisation's Mr Sales plan leaves out — `chat`, `orders`,
  /// `stock`, `products`. Empty in fixture mode and for an organisation nobody
  /// has limited. The database refuses writes to these whatever the app does;
  /// this only stops the app offering a screen that cannot work.
  final Set<String> disabledModules;

  /// The company's rules, read from `org_settings` at sign-in (0049).
  ///
  /// These were constants in the app while the console offered them as
  /// settings, so an owner who widened the fence to 200 m changed nothing on
  /// any phone. Fixture mode keeps the old defaults, which is what the demo
  /// was built against.
  final GeoFencePolicy geoFencePolicy;
  final double geoFenceRadiusMeters;

  /// Above this, a claim line needs a bill and a written reason. Null means
  /// the company has not said, and the rule is what is left of the day's
  /// allowance — which is what the app did before the setting was read.
  final double? billRequiredAbove;

  /// A manager set this password (`set_field_login`), so the rep is asked to
  /// choose their own before anything else. The router holds them on that
  /// screen; it is a prompt, not a security boundary.
  final bool mustChangePassword;

  /// The same session after the rep has chosen their own password.
  Session withOwnPassword() => Session(
    employee: employee,
    loginAt: loginAt,
    token: token,
    disabledModules: disabledModules,
    geoFencePolicy: geoFencePolicy,
    geoFenceRadiusMeters: geoFenceRadiusMeters,
    billRequiredAbove: billRequiredAbove,
  );

  UserRole get role => employee.role;
  DataScope get scope => employee.scope;

  bool hasModule(String key) => !disabledModules.contains(key);

  bool get isManager => role.isManager;
  bool get isFieldUser => role.isFieldUser;
}

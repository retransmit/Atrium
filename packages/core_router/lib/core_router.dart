/// Public surface of `core_router`.
///
/// Route vocabulary ([AtriumRoutes]) and the bottom-nav shell
/// ([ScaffoldWithNavBar]) for Atrium. The concrete [GoRouter] is assembled in
/// the app layer where all screens are in scope.
library;

export 'src/routes.dart';
export 'src/scaffold_with_nav_bar.dart';

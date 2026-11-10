// Fictional mock alerts. NOT real JMA data. Area name is fictional ("（架空）").
// Port of mocks/evacuate/src/data/alerts.ts.
import '../state/time.dart';
import '../state/types.dart';
import 'names.dart';

/// Issued 09:40 JST on the demo day.
final int alertIssuedAt = jstOnDemoDay(9, 40);

final Alert alertEarthquake = Alert(
  id: 'eq-20261108-0940',
  type: HazardType.earthquake,
  level: AlertLevel.warning,
  area: minatoBayArea,
  issuedAt: alertIssuedAt,
);

final Alert alertTsunami = Alert(
  id: 'tsunami-20261108-0940',
  type: HazardType.tsunami,
  level: AlertLevel.warning,
  area: minatoBayArea,
  issuedAt: alertIssuedAt,
  expectedHeight: ExpectedHeight.m3,
);

/// Main scenario alerts: earthquake + tsunami warning.
final List<Alert> mainAlerts = [alertEarthquake, alertTsunami];

/// Typical expected height for a tsunami level, used when the demo panel changes the level.
const Map<AlertLevel, ExpectedHeight> defaultHeight = {
  AlertLevel.advisory: ExpectedHeight.m1,
  AlertLevel.warning: ExpectedHeight.m3,
  AlertLevel.emergency: ExpectedHeight.huge,
};

/// Copy of an alert with a different level (for the demo panel's level switch).
Alert withLevel(Alert alert, AlertLevel level) => alert.type == HazardType.tsunami
    ? alert.copyWith(level: level, expectedHeight: defaultHeight[level])
    : alert.copyWith(level: level);

// Reads the `d` of an SVG path, so the mock's artwork is used as it is (no SVG dependency).
// Absolute commands only (M L H V Q C A Z), which is all the artwork uses.
import 'dart:ui';

final RegExp _token = RegExp(r'[MLHVQCAZ]|-?\d*\.?\d+');

Path svgPath(String d) {
  final tokens = _token.allMatches(d).map((m) => m[0]!).toList();
  final path = Path();
  var i = 0;
  var x = 0.0;
  var y = 0.0;
  double next() => double.parse(tokens[i++]);

  while (i < tokens.length) {
    final cmd = tokens[i++];
    if (cmd == 'Z') {
      path.close();
      continue;
    }
    var first = true;
    // A command's numbers may repeat without repeating the letter.
    while (first || (i < tokens.length && !RegExp('[A-Z]').hasMatch(tokens[i]))) {
      switch (cmd) {
        case 'M':
          x = next();
          y = next();
          first ? path.moveTo(x, y) : path.lineTo(x, y);
        case 'L':
          x = next();
          y = next();
          path.lineTo(x, y);
        case 'H':
          x = next();
          path.lineTo(x, y);
        case 'V':
          y = next();
          path.lineTo(x, y);
        case 'Q':
          final (cx, cy) = (next(), next());
          x = next();
          y = next();
          path.quadraticBezierTo(cx, cy, x, y);
        case 'C':
          final (x1, y1, x2, y2) = (next(), next(), next(), next());
          x = next();
          y = next();
          path.cubicTo(x1, y1, x2, y2, x, y);
        case 'A':
          final (rx, ry, rotation, large, sweep) = (next(), next(), next(), next(), next());
          x = next();
          y = next();
          path.arcToPoint(
            Offset(x, y),
            radius: Radius.elliptical(rx, ry),
            rotation: rotation,
            largeArc: large != 0,
            clockwise: sweep != 0,
          );
        default:
          throw FormatException('Unsupported SVG command $cmd in: $d');
      }
      first = false;
    }
  }
  return path;
}

/// `points` of an SVG polygon: "125,222 345,122 345,222".
Path svgPolygon(String points) {
  final n = RegExp(r'-?\d*\.?\d+').allMatches(points).map((m) => double.parse(m[0]!)).toList();
  return Path()
    ..addPolygon([for (var i = 0; i + 1 < n.length; i += 2) Offset(n[i], n[i + 1])], true);
}

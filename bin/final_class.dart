final class Rectangle {
  final int width;
  final int height;
  const Rectangle(this.width, this.height);
}

final rectangleColor = Expando<String>('RectangleColor');

extension PrintRectangle on Rectangle {
  String get description => 'Rectangle(width: $width, height: $height, color: ${rectangleColor[this]})';
}

main() {
  final rect = Rectangle(10, 20);
  rectangleColor[rect] = 'Blue';

  print(rect.description);
}
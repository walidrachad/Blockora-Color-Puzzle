import 'dart:collection';

import 'package:equatable/equatable.dart';

class GridPoint extends Equatable {
  const GridPoint(this.row, this.col);

  final int row;
  final int col;

  GridPoint translate(int rowDelta, int colDelta) =>
      GridPoint(row + rowDelta, col + colDelta);

  @override
  List<Object?> get props => [row, col];

  Map<String, int> toJson() => {'r': row, 'c': col};

  factory GridPoint.fromJson(Map<String, dynamic> json) =>
      GridPoint(json['r'] as int, json['c'] as int);
}

class Piece extends Equatable {
  Piece({
    required this.id,
    required this.color,
    required Iterable<GridPoint> cells,
    this.generationWeight,
  }) : cells = _normalize(cells);

  final String id;
  final int color;
  final List<GridPoint> cells;

  /// Optional explicit weight for pieces whose probability should not change
  /// when their occupied-cell count changes.
  final int? generationWeight;

  int get width =>
      cells.map((cell) => cell.col).reduce((a, b) => a > b ? a : b) + 1;
  int get height =>
      cells.map((cell) => cell.row).reduce((a, b) => a > b ? a : b) + 1;
  int get size => cells.length;

  static List<GridPoint> _normalize(Iterable<GridPoint> input) {
    final points = input.toList(growable: false);
    if (points.isEmpty) {
      throw ArgumentError.value(
        input,
        'cells',
        'A piece needs at least one cell.',
      );
    }
    final minRow = points
        .map((point) => point.row)
        .reduce((a, b) => a < b ? a : b);
    final minCol = points
        .map((point) => point.col)
        .reduce((a, b) => a < b ? a : b);
    final normalized = points
        .map((point) => GridPoint(point.row - minRow, point.col - minCol))
        .toList();
    normalized.sort((a, b) => a.row != b.row ? a.row - b.row : a.col - b.col);
    return UnmodifiableListView(normalized);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'color': color,
    'cells': cells.map((cell) => cell.toJson()).toList(),
    if (generationWeight != null) 'generationWeight': generationWeight,
  };

  factory Piece.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final definition = PieceLibrary.byId[id];
    final savedCells = (json['cells'] as List<dynamic>)
        .map(
          (cell) => GridPoint.fromJson(Map<String, dynamic>.from(cell as Map)),
        )
        .toList();
    return Piece(
      id: id,
      color: json['color'] as int,
      generationWeight:
          json['generationWeight'] as int? ?? definition?.generationWeight,
      // Library IDs always use the current canonical definition. This also
      // migrates an old save that still contains the retired asym cell.
      cells: definition?.cells ?? savedCells,
    );
  }

  @override
  List<Object?> get props => [id, color, cells, generationWeight];
}

class PieceLibrary {
  static GridPoint p(int row, int col) => GridPoint(row, col);

  static final List<Piece> all = [
    Piece(id: 'dot', color: 0, cells: [p(0, 0)]),
    Piece(id: 'duo_h', color: 1, cells: [p(0, 0), p(0, 1)]),
    Piece(id: 'duo_v', color: 1, cells: [p(0, 0), p(1, 0)]),
    Piece(id: 'trio_h', color: 2, cells: [p(0, 0), p(0, 1), p(0, 2)]),
    Piece(id: 'trio_v', color: 2, cells: [p(0, 0), p(1, 0), p(2, 0)]),
    Piece(id: 'quad_h', color: 3, cells: [p(0, 0), p(0, 1), p(0, 2), p(0, 3)]),
    Piece(id: 'quad_v', color: 3, cells: [p(0, 0), p(1, 0), p(2, 0), p(3, 0)]),
    Piece(
      id: 'line_5_h',
      color: 4,
      cells: [p(0, 0), p(0, 1), p(0, 2), p(0, 3), p(0, 4)],
    ),
    Piece(
      id: 'line_5_v',
      color: 4,
      cells: [p(0, 0), p(1, 0), p(2, 0), p(3, 0), p(4, 0)],
    ),
    Piece(
      id: 'square_2',
      color: 5,
      cells: [p(0, 0), p(0, 1), p(1, 0), p(1, 1)],
    ),
    Piece(
      id: 'square_3',
      color: 6,
      cells: [
        p(0, 0),
        p(0, 1),
        p(0, 2),
        p(1, 0),
        p(1, 1),
        p(1, 2),
        p(2, 0),
        p(2, 1),
        p(2, 2),
      ],
    ),
    Piece(
      id: 'rect_wide',
      color: 0,
      cells: [p(0, 0), p(0, 1), p(0, 2), p(1, 0), p(1, 1), p(1, 2)],
    ),
    Piece(
      id: 'rect_tall',
      color: 0,
      cells: [p(0, 0), p(0, 1), p(1, 0), p(1, 1), p(2, 0), p(2, 1)],
    ),
    Piece(id: 'l_left', color: 1, cells: [p(0, 0), p(1, 0), p(2, 0), p(2, 1)]),
    Piece(id: 'l_right', color: 1, cells: [p(0, 1), p(1, 1), p(2, 0), p(2, 1)]),
    Piece(id: 'l_up', color: 2, cells: [p(0, 0), p(0, 1), p(1, 0), p(2, 0)]),
    Piece(id: 'l_down', color: 2, cells: [p(0, 0), p(0, 1), p(1, 1), p(2, 1)]),
    Piece(id: 't_up', color: 3, cells: [p(0, 0), p(0, 1), p(0, 2), p(1, 1)]),
    Piece(id: 't_down', color: 3, cells: [p(0, 1), p(1, 0), p(1, 1), p(1, 2)]),
    Piece(id: 't_left', color: 4, cells: [p(0, 0), p(1, 0), p(1, 1), p(2, 0)]),
    Piece(id: 't_right', color: 4, cells: [p(0, 1), p(1, 0), p(1, 1), p(2, 1)]),
    Piece(id: 'z', color: 5, cells: [p(0, 0), p(0, 1), p(1, 1), p(1, 2)]),
    Piece(id: 's', color: 5, cells: [p(0, 1), p(0, 2), p(1, 0), p(1, 1)]),
    Piece(id: 'corner_tl', color: 6, cells: [p(0, 0), p(0, 1), p(1, 0)]),
    Piece(id: 'corner_tr', color: 6, cells: [p(0, 0), p(0, 1), p(1, 1)]),
    Piece(id: 'stair', color: 0, cells: [p(0, 0), p(1, 0), p(1, 1), p(2, 1)]),
    Piece(
      id: 'asym',
      color: 2,
      cells: [p(0, 0), p(0, 1), p(1, 1), p(2, 1)],
      generationWeight: 5,
    ),
  ];

  static final Map<String, Piece> byId = {
    for (final piece in all) piece.id: piece,
  };
}

class Board extends Equatable {
  Board([List<List<int?>>? cells, List<List<int?>>? placementIds])
    : cells = List.unmodifiable(
        (cells ?? List.generate(8, (_) => List<int?>.filled(8, null)))
            .map((row) => List<int?>.unmodifiable(row))
            .toList(growable: false),
      ),
      placementIds = List.unmodifiable(
        (placementIds ?? List.generate(8, (_) => List<int?>.filled(8, null)))
            .map((row) => List<int?>.unmodifiable(row))
            .toList(growable: false),
      ) {
    if (this.cells.length != 8 || this.cells.any((row) => row.length != 8)) {
      throw ArgumentError('The board must be exactly 8 by 8.');
    }
    if (this.placementIds.length != 8 ||
        this.placementIds.any((row) => row.length != 8)) {
      throw ArgumentError('Board placement IDs must be exactly 8 by 8.');
    }
  }

  final List<List<int?>> cells;
  final List<List<int?>> placementIds;
  static const int size = 8;

  int? operator [](GridPoint point) => cells[point.row][point.col];
  bool inBounds(GridPoint point) =>
      point.row >= 0 && point.row < size && point.col >= 0 && point.col < size;
  int get filledCount => cells.expand((row) => row).whereType<int>().length;
  int get maxPlacementId => placementIds
      .expand((row) => row)
      .whereType<int>()
      .fold(0, (max, value) => value > max ? value : max);

  Board withCell(GridPoint point, int? color, {int? placementId}) {
    final next = cells.map(List<int?>.from).toList();
    final nextPlacementIds = placementIds.map(List<int?>.from).toList();
    next[point.row][point.col] = color;
    nextPlacementIds[point.row][point.col] = color == null ? null : placementId;
    return Board(next, nextPlacementIds);
  }

  Board place(Piece piece, GridPoint origin, {int? placementId}) {
    var next = this;
    for (final cell in piece.cells) {
      next = next.withCell(
        origin.translate(cell.row, cell.col),
        piece.color,
        placementId: placementId,
      );
    }
    return next;
  }

  Board clear(Iterable<GridPoint> points) {
    var next = this;
    for (final point in points) {
      if (next.inBounds(point)) next = next.withCell(point, null);
    }
    return next;
  }

  List<GridPoint> occupiedCells() => [
    for (var row = 0; row < size; row++)
      for (var col = 0; col < size; col++)
        if (cells[row][col] != null) GridPoint(row, col),
  ];

  List<List<int?>> toJson() => cells.map((row) => row.toList()).toList();

  List<List<int?>> placementIdsToJson() =>
      placementIds.map((row) => row.toList()).toList();

  factory Board.fromJson(List<dynamic> json, {List<dynamic>? placementIds}) =>
      Board(
        json
            .map(
              (row) =>
                  (row as List<dynamic>).map((cell) => cell as int?).toList(),
            )
            .toList(),
        placementIds
            ?.map(
              (row) =>
                  (row as List<dynamic>).map((cell) => cell as int?).toList(),
            )
            .toList(),
      );

  @override
  List<Object?> get props => [
    for (final row in cells) ...row,
    for (final row in placementIds) ...row,
  ];
}

class LineSet extends Equatable {
  const LineSet({required this.rows, required this.columns});

  final List<int> rows;
  final List<int> columns;

  int get count => rows.length + columns.length;

  Set<GridPoint> get uniqueCells => {
    for (final row in rows)
      for (var col = 0; col < Board.size; col++) GridPoint(row, col),
    for (final col in columns)
      for (var row = 0; row < Board.size; row++) GridPoint(row, col),
  };

  @override
  List<Object?> get props => [rows, columns];
}

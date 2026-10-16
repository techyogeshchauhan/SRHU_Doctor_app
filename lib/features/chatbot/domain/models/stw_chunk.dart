import 'dart:ui';

/// A normalized bounding box representing a region on a PDF page
/// with coordinates relative to page dimensions (0.0 to 1.0).
class NormalizedBbox {
  final double x;
  final double y;
  final double width;
  final double height;

  const NormalizedBbox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory NormalizedBbox.fromJson(Map<String, dynamic> json) {
    return NormalizedBbox(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: ((json['width'] ?? json['w']) as num).toDouble(),
      height: ((json['height'] ?? json['h']) as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      };

  /// Converts normalized bbox into pixel [Rect] given the rendered page size.
  Rect toPixelRect(Size pageSize) {
    return Rect.fromLTWH(
      x * pageSize.width,
      y * pageSize.height,
      width * pageSize.width,
      height * pageSize.height,
    );
  }
}

/// One answerable unit of a region: a bullet, numbered item or sentence,
/// verbatim from the PDF. [label] is the line it sits under (e.g.
/// "First screen:"); headers are box headings, never shown as answers.
class StwSegment {
  const StwSegment(
    this.text, {
    this.label,
    this.header = false,
    this.boundingBoxes = const [],
    this.labelBoundingBoxes = const [],
  });

  factory StwSegment.fromJson(Map<String, dynamic> j) => StwSegment(
        j['text'] as String,
        label: j['label'] as String?,
        header: j['header'] as bool? ?? false,
        boundingBoxes: [
          for (final b in j['bounding_boxes'] as List<dynamic>? ?? const [])
            NormalizedBbox.fromJson(b as Map<String, dynamic>),
        ],
        labelBoundingBoxes: [
          for (final b
              in j['label_bounding_boxes'] as List<dynamic>? ?? const [])
            NormalizedBbox.fromJson(b as Map<String, dynamic>),
        ],
      );

  final String text;
  final String? label;
  final bool header;
  final List<NormalizedBbox> boundingBoxes;
  final List<NormalizedBbox> labelBoundingBoxes;

  Map<String, dynamic> toJson() => {
        'text': text,
        if (label != null) 'label': label,
        if (header) 'header': true,
        if (boundingBoxes.isNotEmpty)
          'bounding_boxes': boundingBoxes.map((b) => b.toJson()).toList(),
        if (labelBoundingBoxes.isNotEmpty)
          'label_bounding_boxes':
              labelBoundingBoxes.map((b) => b.toJson()).toList(),
      };

  /// Label and text as shown, e.g. "First screen: By 4 weeks postnatal age".
  String get display => label == null ? text : '$label $text';
}

/// A logical clinical section, algorithm, or table chunk/region extracted from an STW PDF.
class StwChunk {
  final String chunkId;
  final String document;
  final int page;
  final String sectionTitle;
  final String type; // "text" | "algorithm" | "table"
  final String text;
  final List<String> keywords;
  final List<NormalizedBbox> boundingBoxes;
  final String? cropImage;
  final List<String> aliases;
  final List<String> exampleQuestions;
  final String? section;

  /// Answer units in reading order (headers included, flagged).
  final List<StwSegment> segments;

  /// Kinds of question this box answers (see tools/annotate_region_intents.py).
  final List<String> intents;

  const StwChunk({
    required this.chunkId,
    required this.document,
    required this.page,
    required this.sectionTitle,
    required this.type,
    required this.text,
    required this.keywords,
    required this.boundingBoxes,
    this.cropImage,
    this.aliases = const [],
    this.exampleQuestions = const [],
    this.section,
    this.segments = const [],
    this.intents = const [],
  });

  /// Exact evidence for the displayed answer, retaining separate sentences /
  /// table rows. Legacy chunks without sentence coordinates use their card.
  List<NormalizedBbox> boxesForLines(Iterable<StwSegment> lines) {
    final selected = lines.toList();
    if (selected.isEmpty) return boundingBoxes;
    final evidence = <NormalizedBbox>[];
    for (final line in selected) {
      final source = segments
          .where((s) => s.text == line.text && s.label == line.label)
          .firstOrNull;
      if (source == null || source.boundingBoxes.isEmpty) return boundingBoxes;
      evidence.addAll([...source.labelBoundingBoxes, ...source.boundingBoxes]);
    }
    final unique = <String, NormalizedBbox>{};
    for (final b in evidence) {
      unique['${b.x},${b.y},${b.width},${b.height}'] = b;
    }
    return unique.values.toList();
  }

  factory StwChunk.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? json['chunk_id'] as String? ?? '';
    final title = json['title'] as String? ??
        json['section_title'] as String? ??
        'STW Section';
    final doc = json['document'] as String? ?? '';
    final page = json['page'] as int? ?? 1;
    final type = json['type'] as String? ?? 'text';
    final text = json['text'] as String? ?? '';
    final cropImg = json['crop_image'] as String?;
    final sec = json['section'] as String?;

    final aliasList = (json['aliases'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    final questionList = (json['example_questions'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    final kwList = (json['keywords'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();

    // Combined keywords: union of keywords and aliases
    final allKeywords = <String>{...kwList, ...aliasList}.toList();

    List<NormalizedBbox> boxes = [];
    if (json['bounding_boxes'] is List &&
        (json['bounding_boxes'] as List).isNotEmpty) {
      boxes = (json['bounding_boxes'] as List<dynamic>)
          .map((e) => NormalizedBbox.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (json.containsKey('x') &&
        json.containsKey('y') &&
        (json.containsKey('w') || json.containsKey('width')) &&
        (json.containsKey('h') || json.containsKey('height'))) {
      boxes.add(
        NormalizedBbox(
          x: (json['x'] as num).toDouble(),
          y: (json['y'] as num).toDouble(),
          width: ((json['w'] ?? json['width']) as num).toDouble(),
          height: ((json['h'] ?? json['height']) as num).toDouble(),
        ),
      );
    }

    return StwChunk(
      chunkId: id,
      document: doc,
      page: page,
      sectionTitle: title,
      type: type,
      text: text,
      keywords: allKeywords,
      boundingBoxes: boxes,
      cropImage: cropImg,
      aliases: aliasList,
      exampleQuestions: questionList,
      section: sec,
      segments: [
        for (final s in json['segments'] as List<dynamic>? ?? const [])
          StwSegment.fromJson(s as Map<String, dynamic>),
      ],
      intents: [
        for (final i in json['intents'] as List<dynamic>? ?? const [])
          i.toString(),
      ],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': chunkId,
        'chunk_id': chunkId,
        'document': document,
        'page': page,
        'title': sectionTitle,
        'section_title': sectionTitle,
        'type': type,
        'text': text,
        'keywords': keywords,
        'aliases': aliases,
        'example_questions': exampleQuestions,
        'section': section,
        'crop_image': cropImage,
        'bounding_boxes': boundingBoxes.map((b) => b.toJson()).toList(),
        'segments': segments.map((s) => s.toJson()).toList(),
        'intents': intents,
      };
}

/// Result returned by the STW search retriever.
class SearchResult {
  final StwChunk chunk;
  final double score;
  final List<String> matchedTokens;

  const SearchResult({
    required this.chunk,
    required this.score,
    required this.matchedTokens,
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/app_branding.dart';
import '../../condition_selection/domain/neonatal_condition.dart';
import '../../knowledge_graph/ui/stw_map_link.dart';
import '../../references/ui/pdf_viewer_screen.dart';
import '../domain/answering/stw_answer.dart';
import '../domain/models/chat_message.dart';
import '../domain/understanding/query_analyzer.dart';
import '../domain/models/stw_chunk.dart';
import '../state/chatbot_provider.dart';

/// Clinical STW Chatbot Screen grounded exclusively in approved ICMR/DHR PDFs.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  static const List<String> _sampleQueries = [
    'Initial CPAP pressure in preterm ≤34 weeks',
    'Caffeine citrate indication and dosage',
    'Surfactant criteria on CPAP',
    'Whom to screen for ROP',
    'When to do first ROP screening',
    'Treatment indications for ROP',
    'Silverman-Andersen score parameters',
    'CPAP failure and urgent referral',
    'ACS ka dose',
    'Symptoms of neonatal hypoglycemia',
  ];

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submitQuery([String? text]) {
    final query = text ?? _textController.text;
    if (query.trim().isEmpty) return;

    ref.read(chatbotNotifierProvider.notifier).sendQuery(query);
    _textController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _openInPdf(BuildContext context, StwChunk chunk) {
    final assetPath = 'assets/pdfs/${chunk.document}';
    final target = HighlightTarget(
      document: chunk.document,
      page: chunk.page,
      normalizedBboxes: chunk.boundingBoxes
          .map((b) => Rect.fromLTWH(b.x, b.y, b.width, b.height))
          .toList(),
      sectionTitle: chunk.sectionTitle,
      regionId: chunk.chunkId,
    );

    context.push(
      '/pdf-viewer?path=$assetPath&title=${Uri.encodeComponent(chunk.sectionTitle)}',
      extra: {
        'path': assetPath,
        'title': chunk.sectionTitle,
        'highlightTarget': target,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatbotNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        shadowColor: Colors.black12,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryNavy),
          tooltip: 'Back',
          onPressed: () => context.pop(),
        ),
        title: const StwNeoBrand(
          subtitle: 'Clinical STW Query Assistant',
          subtitleSize: 12,
        ),
        actions: [
          if (state.messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh_rounded,
                  color: AppTheme.primaryNavy),
              tooltip: 'Clear Chat',
              onPressed: () {
                ref.read(chatbotNotifierProvider.notifier).clearHistory();
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              children: [
                // Top clinical advisory banner
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: AppTheme.tint,
                  child: Row(
                    children: [
                      const Icon(Icons.verified_outlined,
                          size: 16, color: AppTheme.primaryBlue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Extractive retrieval strictly from ICMR/DHR approved STWs (No LLM generation).',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.primaryNavy,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Chat messages list
                Expanded(
                  child: state.messages.isEmpty
                      ? _buildEmptyState(theme)
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          itemCount:
                              state.messages.length + (state.isLoading ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == state.messages.length &&
                                state.isLoading) {
                              return _buildLoadingBubble();
                            }
                            final msg = state.messages[index];
                            return _buildMessageItem(context, msg, theme);
                          },
                        ),
                ),

                // Quick query chips (when not loading)
                if (!state.isLoading) _buildQuickQueryChips(theme),

                // Bottom query input bar
                _buildInputBar(theme, state.isLoading),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppTheme.tint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              size: 44,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'ICMR Standard Treatment Workflows',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppTheme.primaryNavy,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Ask clinical questions regarding Respiratory Distress in Neonates (RD), Retinopathy of Prematurity (ROP), Antenatal Corticosteroids (ANCS) or Neonatal Hypoglycemia. Answers are extracted directly from the approved STWs with visual PDF highlighting.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.black87,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Suggested Clinical Queries:',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryNavy,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _sampleQueries.map((q) {
              return ActionChip(
                backgroundColor: Colors.white,
                side:
                    BorderSide(color: AppTheme.midBlue.withValues(alpha: 0.3)),
                avatar: const Icon(Icons.search,
                    size: 14, color: AppTheme.primaryBlue),
                label: Text(
                  q,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.primaryNavy,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onPressed: () => _submitQuery(q),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickQueryChips(ThemeData theme) {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _sampleQueries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final q = _sampleQueries[index];
          return ActionChip(
            backgroundColor: Colors.white,
            side: BorderSide(color: AppTheme.midBlue.withValues(alpha: 0.2)),
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            label: Text(
              q,
              style:
                  const TextStyle(fontSize: 11.5, color: AppTheme.primaryBlue),
            ),
            onPressed: () => _submitQuery(q),
          );
        },
      ),
    );
  }

  Widget _buildMessageItem(
      BuildContext context, ChatMessage msg, ThemeData theme) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: const BoxConstraints(maxWidth: 540),
          decoration: const BoxDecoration(
            color: AppTheme.primaryBlue,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            msg.text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    // Bot message card
    final isNotCovered = msg.isNotCovered;
    final answer = msg.answer;
    final isClarify = answer?.kind == AnswerKind.clarify;
    final chunk = answer?.region ?? msg.searchResult?.chunk;
    final condition =
        chunk == null ? null : _conditionOf(topicOfDocument(chunk.document));

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: const BoxConstraints(maxWidth: 580),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
            bottomLeft: Radius.circular(2),
            bottomRight: Radius.circular(14),
          ),
          border: Border.all(
            color: isNotCovered ? const Color(0xFFFCA5A5) : AppTheme.tint,
            width: 1.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header bar of the card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isNotCovered
                    ? const Color(0xFFFEF2F2)
                    : const Color(0xFFF0F6FF),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isNotCovered
                        ? Icons.info_outline
                        : isClarify
                            ? Icons.help_outline_rounded
                            : (chunk?.type == 'algorithm'
                                ? Icons.account_tree_outlined
                                : Icons.menu_book_outlined),
                    size: 16,
                    color: isNotCovered
                        ? Colors.red.shade700
                        : AppTheme.primaryBlue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isNotCovered
                          ? 'Out of Scope'
                          : isClarify
                              ? 'Did you mean…'
                              : (chunk?.sectionTitle ?? 'STW Evidence'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isNotCovered
                            ? Colors.red.shade800
                            : AppTheme.primaryNavy,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (chunk != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        chunk.type.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Extracted text body (verbatim with query highlighting)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (answer?.caseSummary != null) ...[
                    _buildCaseInputs(answer!.caseSummary!.inputs),
                    const SizedBox(height: 10),
                  ],

                  if (answer != null && answer.kind == AnswerKind.answer)
                    _buildAnswerLines(answer.lines)
                  else
                    _buildHighlightedText(
                      msg.text,
                      msg.searchResult?.matchedTokens ?? [],
                      theme,
                    ),

                  // "Did you mean" options: tapping one shows that box.
                  if (isClarify && answer!.options.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final option in answer.options)
                          ActionChip(
                            backgroundColor: Colors.white,
                            side: BorderSide(
                              color: AppTheme.midBlue.withValues(alpha: 0.4),
                            ),
                            label: Text(
                              option.sectionTitle,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppTheme.primaryNavy,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            onPressed: () => ref
                                .read(chatbotNotifierProvider.notifier)
                                .chooseOption(msg, option),
                          ),
                      ],
                    ),
                  ],

                  // Clinician sign-off note from CLINICAL_REVIEW.md
                  if (answer?.caseSummary?.reviewNote != null) ...[
                    const SizedBox(height: 10),
                    _buildNotice(
                      'Requires clinical review: '
                      '${answer!.caseSummary!.reviewNote!}',
                    ),
                  ],

                  // Multi-part completeness notice (e.g. dosage missing)
                  if (msg.missingNotice != null) ...[
                    const SizedBox(height: 10),
                    _buildNotice(msg.missingNotice!),
                  ],

                  // Whole STW box, collapsed under the answer lines
                  if (answer != null &&
                      answer.kind == AnswerKind.answer &&
                      chunk != null)
                    _buildFullBox(chunk)
                  // Cropped region image preview
                  else if (chunk?.cropImage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        color: Colors.white,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        chunk!.cropImage!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Source Badge and "View in PDF" button
            if (chunk != null) ...[
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '📄 ${chunk.document} - Page ${chunk.page}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryNavy,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Highlighted section on page ${chunk.page}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 14),
                      label: const Text(
                        'View in PDF',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      onPressed: () => _openInPdf(context, chunk),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 12, 4),
                child: StwMapLinkButton(
                  focus: chunk.chunkId,
                  file: chunk.document,
                  label: 'Explore related in STW Map',
                ),
              ),
              if (condition != null && answer?.caseSummary != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 12, 6),
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryBlue,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon:
                        const Icon(Icons.playlist_add_check_rounded, size: 18),
                    label: const Text(
                      'Start full assessment',
                      style: TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () => context.push(
                      '/disease-selection',
                      extra: {'condition': condition},
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  static NeonatalCondition? _conditionOf(StwTopic? topic) => switch (topic) {
        StwTopic.rd => NeonatalCondition.respiratoryDistress,
        StwTopic.rop => NeonatalCondition.rop,
        StwTopic.ancs => NeonatalCondition.ancs,
        StwTopic.hypo => NeonatalCondition.hypoglycemia,
        null => null,
      };

  /// The verbatim STW lines that answer the question.
  Widget _buildAnswerLines(List<StwSegment> lines) {
    const style = TextStyle(fontSize: 14, height: 1.45, color: Colors.black87);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (lines.length > 1)
                  const Padding(
                    padding: EdgeInsets.only(top: 7, right: 8),
                    child: Icon(Icons.circle,
                        size: 6, color: AppTheme.primaryBlue),
                  ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: style,
                      children: [
                        if (line.label != null)
                          TextSpan(
                            text: '${line.label} ',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        TextSpan(text: line.text),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Values read from a case question, so the clinician can check them.
  Widget _buildCaseInputs(String inputs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'Read from your question: $inputs',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.primaryNavy,
        ),
      ),
    );
  }

  Widget _buildNotice(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 15,
            color: Color(0xFFB45309),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Whole STW box (text and crop), collapsed under the answer lines.
  Widget _buildFullBox(StwChunk chunk) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Material(
        type: MaterialType.transparency,
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 4),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          dense: true,
          title: const Text(
            'Show full STW box',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryBlue,
            ),
          ),
          children: [
            Text(
              chunk.text,
              style: const TextStyle(
                  fontSize: 13, height: 1.45, color: Colors.black87),
            ),
            if (chunk.cropImage != null) ...[
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                  color: Colors.white,
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  chunk.cropImage!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightedText(
    String fullText,
    List<String> matchedTokens,
    ThemeData theme,
  ) {
    if (matchedTokens.isEmpty) {
      return Text(
        fullText,
        style: const TextStyle(
            fontSize: 13.5, height: 1.45, color: Colors.black87),
      );
    }

    final lowerTokens = matchedTokens.map((t) => t.toLowerCase()).toSet();
    final words = fullText.split(' ');
    final spans = <TextSpan>[];

    for (int i = 0; i < words.length; i++) {
      final w = words[i];
      final clean = w.toLowerCase().replaceAll(RegExp(r'[^\w\.\-%/<≥≤]'), '');
      final isMatch = lowerTokens.contains(clean);

      spans.add(
        TextSpan(
          text: '$w ',
          style: TextStyle(
            fontSize: 13.5,
            height: 1.45,
            color: Colors.black87,
            fontWeight: isMatch ? FontWeight.w700 : FontWeight.w400,
            backgroundColor:
                isMatch ? const Color(0xFFFEF08A) : Colors.transparent,
          ),
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildLoadingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(12)),
          border: Border.fromBorderSide(BorderSide(color: AppTheme.tint)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppTheme.primaryBlue),
            ),
            SizedBox(width: 10),
            Text(
              'Searching approved STWs...',
              style: TextStyle(fontSize: 12.5, color: AppTheme.primaryNavy),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(ThemeData theme, bool isLoading) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submitQuery(),
              decoration: InputDecoration(
                hintText: 'Search clinical condition, algorithm or drug...',
                hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.send_rounded, size: 18),
            onPressed: isLoading ? null : () => _submitQuery(),
          ),
        ],
      ),
    );
  }
}

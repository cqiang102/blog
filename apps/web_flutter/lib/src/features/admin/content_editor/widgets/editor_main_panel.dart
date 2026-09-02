import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:highlight/highlight_core.dart' as highlight;
import 'package:highlight/languages/bash.dart' as highlight_bash;
import 'package:highlight/languages/cpp.dart' as highlight_cpp;
import 'package:highlight/languages/css.dart' as highlight_css;
import 'package:highlight/languages/dart.dart' as highlight_dart;
import 'package:highlight/languages/diff.dart' as highlight_diff;
import 'package:highlight/languages/dockerfile.dart' as highlight_dockerfile;
import 'package:highlight/languages/go.dart' as highlight_go;
import 'package:highlight/languages/gradle.dart' as highlight_gradle;
import 'package:highlight/languages/groovy.dart' as highlight_groovy;
import 'package:highlight/languages/ini.dart' as highlight_ini;
import 'package:highlight/languages/java.dart' as highlight_java;
import 'package:highlight/languages/javascript.dart' as highlight_javascript;
import 'package:highlight/languages/json.dart' as highlight_json;
import 'package:highlight/languages/kotlin.dart' as highlight_kotlin;
import 'package:highlight/languages/markdown.dart' as highlight_markdown;
import 'package:highlight/languages/nginx.dart' as highlight_nginx;
import 'package:highlight/languages/php.dart' as highlight_php;
import 'package:highlight/languages/properties.dart' as highlight_properties;
import 'package:highlight/languages/python.dart' as highlight_python;
import 'package:highlight/languages/ruby.dart' as highlight_ruby;
import 'package:highlight/languages/rust.dart' as highlight_rust;
import 'package:highlight/languages/shell.dart' as highlight_shell;
import 'package:highlight/languages/sql.dart' as highlight_sql;
import 'package:highlight/languages/swift.dart' as highlight_swift;
import 'package:highlight/languages/typescript.dart' as highlight_typescript;
import 'package:highlight/languages/xml.dart' as highlight_xml;
import 'package:highlight/languages/yaml.dart' as highlight_yaml;
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants.dart';
import '../../../../core/markdown_headings.dart';
import '../../../../core/media_url.dart';
import '../../../../theme/app_spacing.dart';
import '../content_editor_state.dart';
import '../markdown_edit_command.dart';
import 'markdown_toolbar.dart';

part 'editor_metadata_fields.dart';
part 'markdown_editor_layout.dart';
part 'markdown_preview.dart';
part 'markdown_preview_support.dart';
part 'markdown_source_editor.dart';

class EditorMainPanel extends StatelessWidget {
  const EditorMainPanel({
    super.key,
    required this.state,
    required this.titleController,
    required this.summaryController,
    required this.bodyController,
    required this.bodyFocusNode,
    required this.onTitleChanged,
    required this.onSummaryChanged,
    required this.onBodyChanged,
    required this.onMarkdownAction,
    required this.onInsertCodeBlockLanguage,
    required this.onInsertImage,
    required this.onOpenTableEditor,
    required this.onEditModeChanged,
    required this.mediaChild,
  });

  final ContentEditorState state;
  final TextEditingController titleController;
  final TextEditingController summaryController;
  final TextEditingController bodyController;
  final FocusNode bodyFocusNode;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<String> onSummaryChanged;
  final ValueChanged<String> onBodyChanged;
  final ValueChanged<MarkdownEditAction> onMarkdownAction;
  final ValueChanged<String> onInsertCodeBlockLanguage;
  final VoidCallback onInsertImage;
  final VoidCallback onOpenTableEditor;
  final ValueChanged<EditorEditMode> onEditModeChanged;
  final Widget mediaChild;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ..._buildEditorMetadataFields(
          context: context,
          titleController: titleController,
          summaryController: summaryController,
          onTitleChanged: onTitleChanged,
          onSummaryChanged: onSummaryChanged,
        ),
        const SizedBox(height: AppSpacing.md),
        if (state.isMediaType)
          mediaChild
        else
          _MarkdownPanel(
            state: state,
            bodyController: bodyController,
            bodyFocusNode: bodyFocusNode,
            onBodyChanged: onBodyChanged,
            onMarkdownAction: onMarkdownAction,
            onInsertCodeBlockLanguage: onInsertCodeBlockLanguage,
            onInsertImage: onInsertImage,
            onOpenTableEditor: onOpenTableEditor,
            onEditModeChanged: onEditModeChanged,
          ),
      ],
    );
  }
}

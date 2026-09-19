import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

class NoteEditorScreen extends StatefulWidget {
  final String title;

  const NoteEditorScreen({super.key, required this.title});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final EditorState _editorState = EditorState.blank();

  @override
  void dispose() {
    _editorState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: AppFlowyEditor(editorState: _editorState),
    );
  }
}

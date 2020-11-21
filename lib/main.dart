import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      home: MyHomePage(title: 'Notepad App'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  _initializeFirebase() async {
    await Firebase.initializeApp();
  }

  _addNote() {
    final res = FirebaseFirestore.instance
        .collection('notes')
        .add({"created": DateTime.now()});
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditNotePage(futureId: res),
      ),
    );
  }

  Future<void> updateNote(Map<String, dynamic> updatedNote, String id) =>
      FirebaseFirestore.instance
          .collection('notes')
          .doc(id)
          .update(updatedNote);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNote,
        child: Icon(Icons.add),
      ),
      body: FutureBuilder(
        future: _initializeFirebase(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(
              child: Text("There was an error =("),
            );

          if (snapshot.connectionState == ConnectionState.done)
            return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('notes')
                    .orderBy("created", descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final notes = snapshot.data.docs;
                    return ListView.builder(
                        itemCount: notes.length,
                        itemBuilder: (context, index) {
                          final note = notes[index];
                          return ListTile(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EditNotePage(
                                  id: note.id,
                                  title: note.data()["title"],
                                  body: note.data()["body"],
                                  updateNote: updateNote,
                                ),
                              ),
                            ),
                            title: Text(note.data()["title"] ?? "Untitled"),
                            trailing: Icon(
                              Icons.chevron_right_outlined,
                            ),
                          );
                        });
                  }
                  return LoadingWidget();
                });
          return LoadingWidget();
        },
      ),
    );
  }
}

class LoadingWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(),
    );
  }
}

class EditNotePage extends StatefulWidget {
  final String id;
  final Future<DocumentReference> futureId;
  final String title;
  final String body;
  final Function(Map<String, dynamic>, String) updateNote;

  const EditNotePage(
      {Key key, this.id, this.title, this.body, this.futureId, this.updateNote})
      : super(key: key);

  @override
  _EditNotePageState createState() => _EditNotePageState();
}

class _EditNotePageState extends State<EditNotePage> {
  TextEditingController _titleController;
  TextEditingController _bodyController;
  String _id;
  StreamSubscription _noteSub;

  final _updateNoteController = StreamController();
  final _loadingController = StreamController<bool>();

  Map<String, dynamic> get currentNote =>
      {"title": _titleController.text, "body": _bodyController.text};

  @override
  void initState() {
    _titleController = TextEditingController(text: widget.title);
    _bodyController = TextEditingController(text: widget.body);

    _noteSub = _updateNoteController.stream
        .debounceTime(Duration(seconds: 1))
        .listen((updatedNote) async {
      _loadingController.add(true);
      await widget.updateNote(currentNote, _id);
      _loadingController.add(false);
    });

    if (widget.futureId != null) {
      widget.futureId.then((value) => _id = value.id);
    } else {
      _id = widget.id;
    }
    print(widget.updateNote);

    super.initState();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _updateNoteController.close();
    _loadingController.close();
    _noteSub.cancel();
    widget.updateNote(currentNote, _id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Column(
                children: [
                  TextField(
                    controller: _titleController,
                    onChanged: (title) => _updateNoteController.add(title),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: "Title",
                      hintStyle: TextStyle(fontWeight: FontWeight.normal),
                      border: InputBorder.none,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _bodyController,
                      onChanged: (body) => _updateNoteController.add(body),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: "Note",
                      ),
                      expands: true,
                      maxLines: null,
                    ),
                  )
                ],
              ),
              Positioned(
                top: 5,
                right: 5,
                child: StreamBuilder(
                  stream: _loadingController.stream,
                  initialData: false,
                  builder: (context, snapshot) =>
                      snapshot.data ? LoadingWidget() : Container(),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

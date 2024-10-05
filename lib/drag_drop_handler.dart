import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_clipboard/src/reader.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import 'package:wispatisfactory/extensions.dart';
import 'package:wispatisfactory/logging.dart';
import 'package:wispatisfactory/sbp_file_parser.dart';

class DragDropHandler extends ConsumerStatefulWidget {
  final Widget child;
  final void Function(String)? onDroppedLog;

  const DragDropHandler({super.key, required this.child, this.onDroppedLog});

  @override
  ConsumerState createState() => _DragDropHandlerState();
}

class _DragDropHandlerState extends ConsumerState<DragDropHandler> {
  bool _dragging = false;
  bool _inProgress = false;
  List<DropItem>? hoveredEvents;

  // Offset? _offset;
  static int _lastDropTimestamp = 0;
  static const _minDropInterval = 400;

  @override
  Widget build(BuildContext context) {
    return DropRegion(
      formats: Formats.standardFormats,
      onPerformDrop: (detail) async {
        // The onDragDone callback is called twice for the same drop event, add a timer to avoid it.
        if (DateTime.now().millisecondsSinceEpoch - _lastDropTimestamp < _minDropInterval) {
          return;
        } else {
          _lastDropTimestamp = DateTime.now().millisecondsSinceEpoch;
        }

        final droppedItems = detail.session.items;

        Fimber.i("Dropped ${droppedItems.length} files.");
        // Fimber.i("Dropped ${detail.files.length} files at $_offset");

        if (droppedItems.isEmpty) {
          return;
        }

        final files = (await Future.wait(droppedItems.map((e) async {
          final reader = e.dataReader;
          if (reader == null) return null;

          // File
          if (reader.canProvide(Formats.fileUri)) {
            Fimber.i("Dropped file: ${await reader.getSuggestedName()}");
            return await getFileFromReader(reader);
          } else if (reader.canProvide(Formats.uri)) {
            Fimber.i("Dropped uri: ${await reader.getSuggestedName()}");
            final uri = await getUriFromReader(reader);
            if (uri == null) return null;

            return null;
          }

          return null;
        })))
            .whereNotNull()
            .toList();

        if (files.isEmpty) {
          Fimber.i("No files dropped.");
          return;
        }

        if (files.any((file) => file is File && file.extension.equalsAnyIgnoreCase([".sbp"]))) {
          {
            setState(() {
              _inProgress = true;
            });
            try {
              // Install each dropped archive in turn.
              // Log any errors and continue with the next archive.
              for (var filePath in files) {
                SBPFile sbpFile = SBPFile(filePath.path);
                await sbpFile.modify(beltMk: 5, liftMk: 5);
                // append " (releveled)" to the end of the file name
                final newFile = filePath.path.replaceFirstMapped(RegExp(r'(\.sbp)$'), (match) => " (releveled).sbp");
                if (filePath.path == newFile) {
                  Fimber.e("New path is same as old, aborting: $filePath");
                  continue;
                }
                await sbpFile.write(newFile);
              }
            } finally {
              setState(() {
                _inProgress = false;
              });
            }
          }
        }
      },
      // onDragUpdated: (details) {
      //   setState(() {
      //     _offset = details.localPosition;
      //   });
      // },
      onDropOver: (detail) async {
        if (detail.session.items.isEmpty) {
          return DropOperation.none;
        } else if (detail.session.items.hashCode == hoveredEvents.hashCode) {
          return DropOperation.copy;
        }

        // final files = (await Future.wait(detail.session.items.map((e) async {
        //   final reader = e.dataReader;
        //   if (reader == null) return null;
        //
        //   // File
        //   var name = await reader.getSuggestedName();
        //   if (reader.canProvide(Formats.fileUri)) {
        //     Fimber.i("Dropped file: $name");
        //     return name;
        //   } else if (reader.canProvide(Formats.uri)) {
        //     Fimber.i("Dropped uri: $name");
        //     return name;
        //   }
        //
        //   return null;
        // })))
        //     .whereNotNull()
        //     .toList()

        final files = (await filterToSupportedTypes(detail.session.items)).orEmpty().toList();
        if (files.isEmpty) {
          return DropOperation.none;
        }

        setState(() {
          _dragging = true;
          hoveredEvents = files;
          // _offset = detail.localPosition;
        });
        return DropOperation.copy;
      },
      onDropEnter: (detail) {
        setState(() {
          _dragging = true;
          // _offset = detail.session.localPosition;
        });
      },
      onDropLeave: (detail) {
        setState(() {
          _dragging = false;
          // _offset = null;
          hoveredEvents = null;
        });
      },
      child: Stack(
        children: [
          widget.child,
          IgnorePointer(
            child: Container(
                color: _dragging ? Colors.blue.withOpacity(0.4) : Colors.transparent,
                child: _inProgress
                    ? const Center(child: CircularProgressIndicator())
                    : hoveredEvents != null
                        ? SizedBox(
                            width: double.infinity,
                            height: double.infinity,
                            child: Center(
                              child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: FutureBuilder(
                                      future: Future.wait(hoveredEvents!.map((event) async {
                                        if (event.dataReader == null) {
                                          return null;
                                        } else if (event.dataReader!.canProvide(Formats.fileUri)) {
                                          return await getFileFromReader(event.dataReader!);
                                        } else if (event.dataReader!.canProvide(Formats.uri)) {
                                          return (await getUriFromReader(event.dataReader!))?.uri;
                                        }
                                      })),
                                      builder: (context, future) {
                                        return IntrinsicHeight(
                                          child: IntrinsicWidth(
                                            child: ConstrainedBox(
                                              constraints: const BoxConstraints(minWidth: 400),
                                              child: Column(
                                                children: future.data
                                                    .orEmpty()
                                                    .whereNotNull()
                                                    .whereType<File>()
                                                    .map((file) => Text(file.path))
                                                    .toList(),
                                                // urls: future.data
                                                //     .orEmpty()
                                                //     .whereNotNull()
                                                //     .whereType<Uri>()
                                                //     .toList(),
                                              ),
                                            ),
                                          ),
                                        );
                                      })),
                            ),
                          )
                        : null),
          ),
        ],
      ),
    );
  }

  Future<FileSystemEntity?> getFileFromReader(DataReader reader) async {
    final completer = Completer<String?>();
    reader.getValue(Formats.fileUri, (fileUri) {
      final filePath = fileUri?.toFilePath(windows: Platform.isWindows);
      Fimber.v(() => "Got dropped file uri: $filePath");
      completer.complete(filePath);
    });
    return (await completer.future)?.let((path) => File(path));
  }

  Future<NamedUri?> getUriFromReader(DataReader reader) async {
    final completer = Completer<NamedUri?>();
    reader.getValue(Formats.uri, (uri) {
      Fimber.v(() => "Got dropped uri: ${uri?.uri}");
      completer.complete(uri);
    });
    return await completer.future;
  }

  Future<List<DropItem>?> filterToSupportedTypes(List<DropItem> items) async {
    List<DropItem> supportedItems = [];

    for (var item in items) {
      final reader = item.dataReader;
      if (reader == null) continue;

      if (reader.canProvide(Formats.fileUri)) {
        if ((await getFileFromReader(reader))?.isFile() == true) {
          supportedItems.add(item);
        }
      } else if (reader.canProvide(Formats.uri)) {
        supportedItems.add(item);
      }
    }

    return supportedItems;
  }
}

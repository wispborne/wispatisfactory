import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

void main() async {
  File file = File('F:/Downloads/Vertical Merger Mk4.sbp');
  File outFile = File(
      'C:/Users/whitm/AppData/Local/FactoryGame/Saved/SaveGames/blueprints/Wispborne/Vertical Merger Mk5 test.sbp');
  final oldString = 'Build_ConveyorLiftMk4_C';
  final newString = 'Build_ConveyorLiftMk5_C';

  // Read the binary file
  final Uint8List bytes = await file.readAsBytes();

  // Convert strings to byte arrays (assuming ASCII encoding)
  final oldStringBytes = ascii.encode(oldString + '\0'); // null-terminated
  final newStringBytes = ascii.encode(newString + '\0'); // null-terminated

// Find occurrences of the old string in the file
  for (int i = 0; i < bytes.length - oldStringBytes.length; i++) {
    bool match = true;

    // Check if all bytes match
    for (int j = 0; j < oldStringBytes.length; j++) {
      if (bytes[i + j] != oldStringBytes[j]) {
        match = false;
        break;
      }
    }

    if (match) {
      // Replace the old string with the new string
      for (int j = 0; j < newStringBytes.length; j++) {
        bytes[i + j] = newStringBytes[j];
      }
    }
  }

  // Write the modified bytes back to the file
  await outFile.writeAsBytes(bytes);
  print('Replacements complete.');
}

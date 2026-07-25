import 'dart:convert';
import 'dart:io';

void main() async {
  // Read tokenizer.json
  final file = File('lib/features/sigiriya_guide/heritageAR-chatbot/models/all-MiniLM-L6-v2/tokenizer.json');
  final content = await file.readAsString();
  final data = jsonDecode(content) as Map<String, dynamic>;
  
  // Extract vocab
  final vocab = data['model']['vocab'] as Map<String, dynamic>;
  
  // Create assets/data directory
  final dataDir = Directory('assets/data');
  if (!await dataDir.exists()) {
    await dataDir.create(recursive: true);
  }
  
  // Sort by token ID and write to vocab.txt
  final sortedEntries = vocab.entries.toList()
    ..sort((a, b) => (a.value as int).compareTo(b.value as int));
  
  final outputFile = File('assets/data/vocab.txt');
  final sink = outputFile.openWrite();
  
  for (final entry in sortedEntries) {
    sink.writeln(entry.key);
  }
  
  await sink.close();
  
  print('Vocab extracted successfully: ${vocab.length} tokens');
}

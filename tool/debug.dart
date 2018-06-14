import 'dart:async';
import 'dart:io';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;

main(List<String> args) async {
  var argParser = new ArgParser()
    ..addOption('exec',
        abbr: 'n',
        defaultsTo: 'lldb',
        help: 'The command to run.',
        allowed: ['lldb', 'gdb', 'valgrind'])
    ..addOption('script',
        abbr: 's',
        defaultsTo: 'example/main.dart',
        help: 'The script to run, relative to ${Platform.script}')
    ..addMultiOption('commands',
        abbr: 'x',
        splitCommas: true,
        help: 'Additional LLDB commands to run before starting Dart.');

  try {
    var argResults = argParser.parse(args);
    var projectDir = p.dirname(p.dirname(p.fromUri(Platform.script)));
    var scriptPath = p.absolute(p.join(projectDir, argResults['script']));

    print('Press CTRL-C to quit.');
    //print('Press CTRL-Z to reload.');

    await runCmake(projectDir);

    var pargs = [];
    if (argResults['exec'] == 'valgrind')
      pargs.addAll([
        '--leak-check=yes',
        //'--track-origins=yes',
      ]);
    pargs.addAll([Platform.resolvedExecutable, scriptPath]);

    var process =
        await Process.start(argResults['exec'], pargs, runInShell: false);
    process..stdout.listen(stdout.add)..stderr.listen(stderr.add);

    for (var command in argResults['commands']) {
      process.stdin.writeln(command);
    }

    process.stdin.writeln('run');

    ProcessSignal.sigint.watch().listen((ProcessSignal signal) {
      process.stdin..writeln('quit')..writeln('y');
      new Future.delayed(const Duration(seconds: 1)).then((_) => exit(0));
    });

    /*
    ProcessSignal.sighup.watch().listen((_) async {
      await runCmake(projectDir);
      process.stdin.writeln('directory');
    });
    */

    exit(await process.exitCode);
  } on ArgParserException catch (e) {
    stderr
      ..write('fatal error: ')
      ..writeln(e.message)
      ..writeln()
      ..writeln(argParser.usage);
  }
}

Future runCmake(String projectDir) async {
  var process = await Process.start(
      'cmake', ['--build', '.', '--', '-j${Platform.numberOfProcessors}'],
      workingDirectory: p.absolute(projectDir), runInShell: false);
  process..stdout.listen(stdout.add)..stderr.listen(stderr.add);
  var code = await process.exitCode;
  if (code != 0) exit(code);
}

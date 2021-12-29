import 'dart:ffi';
import 'dart:ffi' as ffi;
import 'dart:io' show Directory, Platform;
import 'dart:isolate';
import 'dart:typed_data';
import 'package:path/path.dart' as path;

void main() async {
  // Initialise allo-isolate
  init();

  // Wait for a bit so we can open the debug console
  print("Sleep for 20 seconds");
  await Future.delayed(Duration(seconds: 20));

  await create_rust_objects();
  await create_dart_objects();
}

// FFI signature of the dartPostCObject C function
typedef dartPostCObject = Pointer Function(
    Pointer<NativeFunction<Int8 Function(Int64, Pointer<Dart_CObject>)>>);

// FFI signature of the create_object C function
typedef CreateObjectFunc = ffi.Void Function(Int64);
// Dart type definition for calling the C foreign function
typedef CreateObject = void Function(int port);

// FFI signature of the inspect_object C function
typedef InspectObjectFunc = ffi.Void Function(Pointer<Dart_CObject>);
// Dart type definition for calling the C foreign function
typedef InspectObject = void Function(Pointer<Dart_CObject>);

Future<void> create_rust_objects() async {
  final lib = library();

  // Generate 10 objects of 1GB each on the Rust heap
  for (var i = 1; i <= 10; i++) {
    ReceivePort receivePort = ReceivePort();
    final port = receivePort.sendPort.nativePort;

    // Create a 1GB object on the Rust side
    print("Allocating $i GB...");
    create_object(lib, port);

    // Get the pointer back
    final response = await receivePort.first;
    if (response is int) {
      print("Pointer received in Dart: $response");

      // Convert it to a pointer and pass it back to Rust (read-only)
      Pointer<Dart_CObject> pointer = Pointer.fromAddress(response);
      inspect_object(lib, pointer);
    } else {
      print("Received an unexpected response: ${response}");
    }
  }
}

Future<void> create_dart_objects() async {
  print("Sleep for 10 seconds...");
  await Future.delayed(Duration(seconds: 10));

  // Generate many objects on the Dart heap
  print("Generating many objects on the Dart heap...");

  // This will be garbage collected fairly quickly
  for (var i = 0; i < 10 * 1024; i++) {
    // 1MB worth of data
    var list = Uint8List(1024 * 1024);
    list.fillRange(0, 1024 * 1024, 42);
    if (i % 1000 == 0) {
      print("\tAllocating ${(i / 1000).round() + 1} GB...");
    }
  }

  // Keep the program alive for memory inspection
  print("Sleep for a while...");
  await Future.delayed(Duration(days: 42));
}

/// Rust function that allocates an object on the heap
void create_object(DynamicLibrary lib, port) {
  final func = lib
      .lookup<NativeFunction<CreateObjectFunc>>('create_object')
      .asFunction<CreateObject>();
  func(port);
}

/// Rust function that inspects an object
void inspect_object(DynamicLibrary lib, Pointer<Dart_CObject> object) {
  final func = lib
      .lookup<NativeFunction<InspectObjectFunc>>('inspect_object')
      .asFunction<InspectObject>();
  func(object);
}

/// Initialize storeDartPostCObject
void init() {
  final storeDartPostCObject =
      library().lookupFunction<dartPostCObject, dartPostCObject>(
    'store_dart_post_cobject',
  );
  storeDartPostCObject(NativeApi.postCObject);
}

/// Find the right dynamic library
DynamicLibrary library() {
  // Open the dynamic library
  var libraryPath = path.join(
      Directory.current.path, 'rustlib', 'target', 'debug', 'librustlib.so');
  if (Platform.isMacOS) {
    libraryPath = path.join(Directory.current.path, 'rustlib', 'target',
        'x86_64-apple-darwin', 'debug', 'librustlib.dylib');
  }
  if (Platform.isWindows) {
    libraryPath = path.join(
        Directory.current.path, 'rustlib', 'target', 'Debug', 'librustlib.dll');
  }
  return DynamicLibrary.open(libraryPath);
}

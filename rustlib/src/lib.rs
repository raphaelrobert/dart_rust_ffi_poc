use std::{ffi::c_void, mem};

use allo_isolate::{
    ffi::{DartCObject, DartCObjectValue, DartNativePointer},
    *,
};

const GB: usize = 1024 * 1024 * 1024;

#[no_mangle]
pub extern "C" fn create_object(port: i64) {
    let size = GB;
    let isolate = Isolate::new(port);
    let object = vec![42u8; size];
    let ptr = Box::into_raw(Box::new(object));
    println!("Creating Rust object with pointer: {}", ptr as isize);
    let dart_object = DartCObject {
        ty: ffi::DartCObjectType::DartNativePointer,
        value: DartCObjectValue {
            as_native_pointer: DartNativePointer {
                ptr: ptr as isize,
                size: size as isize,
                callback,
            },
        },
    };
    if isolate.post(dart_object) {
        println!("\tObject created successfully!")
    } else {
        println!("\tObject could not be created.")
    }
}

/// # Safety
/// This function uses `unsafe`.
#[no_mangle]
pub unsafe extern "C" fn callback(isolate_callback_data: *mut c_void, peer: *mut c_void) {
    println!(
        "GC: Received pointer {} and peer {}",
        isolate_callback_data as isize, peer as isize
    );
    // The pointer is in the peer parameter
    let object = Box::from_raw(peer);
    println!("\tInstantiated object.");
    // We just drop the object
    drop(object);
    println!("\tDropped object.");
}

/// # Safety
/// This function uses `unsafe`.
#[no_mangle]
pub unsafe extern "C" fn inspect_object(dart_c_object: *mut c_void) {
    println!("Inspecting object with pointer {}", dart_c_object as isize);
    let object = Box::from_raw(dart_c_object as *mut Vec<u8>);
    println!("\tInstantiated object.");
    // We can inspect the object here
    assert_eq!(object.len(), GB);
    assert_eq!(object[0], 42u8);
    // Avoid deallocating
    mem::forget(object);
    println!("\tForgot object.");
}

import Foundation
import SimulatorKit
import CoreSimulator
import AppKit

import os

@objc class SimulatorSupport : NSObject, SimDeviceUserInterfacePlugin {
    
    private let device: SimDevice
    private let hid_client: SimDeviceLegacyHIDClient

    @objc init(with device: SimDevice) {
        self.device = device
        os_log("XRGyroControls: Initialized with device: \(device)")
        self.hid_client = try! SimDeviceLegacyHIDClient(device: device)
        os_log("XRGyroControls: Initialized HID client")
        super.init()

        DispatchQueue.global().async {
            self.openxr_thread()
        }
    }

    @objc func openxr_thread() {
        Thread.sleep(forTimeInterval: 1.0)

        //print("OpenXR thread start!")

        ObjCBridge_Startup();

        var asdf: Int = 0
        while (true) {
            let pose = ObjCBridge_Loop().pointee;
            //let pose = self.openxr_wrapper.get_data()
            
            hid_client.send(message: IndigoHIDMessage.pose(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0).as_struct())
            hid_client.send(message: IndigoHIDMessage.manipulator(asdf, pose).as_struct())

            asdf += 1
            if (asdf > 120) {
                asdf = 0
            }

            Thread.sleep(forTimeInterval: 0.008)
            //Thread.sleep(forTimeInterval: 0.5)
        }

        ObjCBridge_Shutdown();
        //print("OpenXR thread end!")
        //self.openxr_wrapper.cleanup()
    }
    
    func send_test_message(_ cnt: Int) {
        hid_client.send(message: IndigoHIDMessage.pose(0.0, Float(cnt) / 1000, 0.0, 0.0, 0.0, 0.0, 1.0).as_struct())
    }
    
    @objc func overlayView() -> NSView {
        return NSView()
    }
    
    @objc func toolbar() -> NSToolbar {
        return NSToolbar()
    }
}
/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A view controller that facilitates the Nearby Interaction Accessory user experience.
*/

import UIKit
import NearbyInteraction
import os.log
import Foundation

// An example messaging protocol for communications between the app and the
// accessory. In your app, modify or extend this enumeration to your app's
// user experience and conform the accessory accordingly.
enum MessageId: UInt8 {
    // Messages from the accessory.
    case accessoryConfigurationData = 0x1
    case accessoryUwbDidStart = 0x2
    case accessoryUwbDidStop = 0x3
    
    // Messages to the accessory.
    case initialize = 0xA
    case configureAndStart = 0xB
    case stop = 0xC
}

class AccessoryDemoViewController: UIViewController {
    var dataChannel = DataCommunicationChannel()
    var niSessionA = NISession()
    var niSessionB = NISession()
    var niSessionC = NISession()
    var configuration: NINearbyAccessoryConfiguration?
    var accessoryConnected = false
    var connectedAccessoryName: String?
    // A mapping from a discovery token to a name.
    var accessoryMap = [NIDiscoveryToken: String]()

    let logger = os.Logger(subsystem: "com.example.apple-samplecode.NINearbyAccessorySample", category: "AccessoryDemoViewController")

    //@IBOutlet weak var connectionStateLabel: UILabel!
    //@IBOutlet weak var uwbStateLabel: UILabel!
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var positionLabelA: UILabel!
    @IBOutlet weak var positionLabelB: UILabel!
    @IBOutlet weak var positionLabelC: UILabel!
    @IBOutlet weak var distanceLabelA: UILabel!
    @IBOutlet weak var distanceLabelB: UILabel!
    @IBOutlet weak var distanceLabelC: UILabel!
    @IBOutlet weak var positionLabel: UILabel!
    //@IBOutlet weak var actionButton: UIButton!
    @IBOutlet weak var Connect_A: UIButton!
    @IBOutlet weak var Connect_B: UIButton!
    @IBOutlet weak var Connect_C: UIButton!
    
    //地点の座標と半径を定義
    let xa:Float = 3.0, ya:Float = 3.0, za:Float = 2.2
    let xb:Float = 3.0, yb:Float = 0.0, zb:Float = 2.2
    let xc:Float = 0.0, yc:Float = 3.0, zc:Float = 2.2
    var ra:Float = 0.0
    var rb:Float = 0.0
    var rc:Float = 0.0
    
    // 初期値、学習率、反復回数を設定
    let initialPoint: (Float, Float, Float) = (0.0, 0.0, 0.0)
    let learningRate: Float = 0.3
    let iterations: Int = 30
    
    
    //positionLabelA.text=String(format:"%.2f,%.2f,%.2f",xa,ya,za)
    //positionLabelB.text=String(format:"%.2f,%.2f,%.2f",xb,yb,zb)
    //positionLabelC.text=String(format:"%.2f,%.2f,%.2f",xc,yc,zc)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set a delegate for session updates from the framework.
        niSessionA.delegate = self
        niSessionB.delegate = self
        niSessionC.delegate = self
        
        // Prepare the data communication channel.
        dataChannel.accessoryConnectedHandler = accessoryConnected
        dataChannel.accessoryDisconnectedHandler = accessoryDisconnected
        dataChannel.accessoryDataHandler = accessorySharedData
        dataChannel.start()
        
        updateInfoLabel(with: "Scanning for accessories")
    }
    
    @IBAction func buttonAction(_ sender: Any) {
        updateInfoLabel(with: "Requesting configuration data from accessory")
        let msg = Data([MessageId.initialize.rawValue])
        sendDataToAccessory(msg)
    }
    
    // MARK: - Data channel methods
    
    func accessorySharedData(data: Data, accessoryName: String) {
        // The accessory begins each message with an identifier byte.
        // Ensure the message length is within a valid range.
        if data.count < 1 {
            updateInfoLabel(with: "Accessory shared data length was less than 1.")
            return
        }
        
        // Assign the first byte which is the message identifier.
        guard let messageId = MessageId(rawValue: data.first!) else {
            fatalError("\(data.first!) is not a valid MessageId.")
        }
        
        // Handle the data portion of the message based on the message identifier.
        switch messageId {
        case .accessoryConfigurationData:
            // Access the message data by skipping the message identifier.
            assert(data.count > 1)
            let message = data.advanced(by: 1)
            setupAccessory(message, name: accessoryName)
        case .accessoryUwbDidStart:
            handleAccessoryUwbDidStart()
        case .accessoryUwbDidStop:
            handleAccessoryUwbDidStop()
        case .configureAndStart:
            fatalError("Accessory should not send 'configureAndStart'.")
        case .initialize:
            fatalError("Accessory should not send 'initialize'.")
        case .stop:
            fatalError("Accessory should not send 'stop'.")
        }
    }
    
    func accessoryConnected(name: String) {
        accessoryConnected = true
        connectedAccessoryName = name
        if dataChannel.TagNumber == 0 {
            Connect_A.isEnabled = true
        }
        else if dataChannel.TagNumber == 1 {
            Connect_B.isEnabled = true
        }
        else if dataChannel.TagNumber == 2 {
            Connect_C.isEnabled = true
        }
        //connectionStateLabel.text = "Connected"
        updateInfoLabel(with: "Connected to '\(name)'")
    }
    
    func accessoryDisconnected() {
        Connect_A.isEnabled=false
        Connect_B.isEnabled=false
        Connect_C.isEnabled=false
        
        accessoryConnected = false
        connectedAccessoryName = nil
        dataChannel.TagNumber += 1
        //connectionStateLabel.text = "Not Connected"
        updateInfoLabel(with: "Accessory disconnected")
    }
    
    // MARK: - Accessory messages handling
    
    func setupAccessory(_ configData: Data, name: String) {
        updateInfoLabel(with: "Received configuration data from '\(name)'. Running session.")
        do {
            configuration = try NINearbyAccessoryConfiguration(data: configData)
        } catch {
            // Stop and display the issue because the incoming data is invalid.
            // In your app, debug the accessory data to ensure an expected
            // format.
            updateInfoLabel(with: "Failed to create NINearbyAccessoryConfiguration for '\(name)'. Error: \(error)")
            return
        }
        
        // Cache the token to correlate updates with this accessory.
        cacheToken(configuration!.accessoryDiscoveryToken, accessoryName: name)
        if(dataChannel.TagNumber==0){
            niSessionA.run(configuration!)
        }
        else if(dataChannel.TagNumber==1){
            niSessionB.run(configuration!)
        }
        else if(dataChannel.TagNumber==2){
            niSessionC.run(configuration!)
        }
    }
    
    func handleAccessoryUwbDidStart() {
        updateInfoLabel(with: "Accessory session started.")
        if dataChannel.TagNumber == 0 {
            Connect_A.isEnabled = false
        }
        else if dataChannel.TagNumber == 1 {
            Connect_B.isEnabled = false
        }
        else if dataChannel.TagNumber == 2 {
            Connect_C.isEnabled = false
        }
        dataChannel.disConnect()
        
        //self.uwbStateLabel.text = "ON"
    }
    
    func handleAccessoryUwbDidStop() {
        updateInfoLabel(with: "Accessory session stopped.")
        if accessoryConnected {
            //actionButton.isEnabled = true
        }
        //self.uwbStateLabel.text = "OFF"
    }
    
    //以下座標を求める
    // 目的関数の勾配を計算する関数
    func gradient(at point: (Float, Float, Float)) -> (Float, Float, Float) {
        let (x, y, z) = point
        
        // 各地点からの距離
        let dA = sqrt(pow(x - xa, 2) + pow(y - ya, 2) + pow(z - za, 2))
        let dB = sqrt(pow(x - xb, 2) + pow(y - yb, 2) + pow(z - zb, 2))
        let dC = sqrt(pow(x - xc, 2) + pow(y - yc, 2) + pow(z - zc, 2))
        
        // 勾配計算
        let gradX = 2 * ((dA - ra) * (x - xa) / dA + (dB - rb) * (x - xb) / dB + (dC - rc) * (x - xc) / dC)
        let gradY = 2 * ((dA - ra) * (y - ya) / dA + (dB - rb) * (y - yb) / dB + (dC - rc) * (y - yc) / dC)
        let gradZ = 2 * ((dA - ra) * (z - za) / dA + (dB - rb) * (z - zb) / dB + (dC - rc) * (z - zc) / dC)
        
        return (gradX, gradY, gradZ)
    }

    // 勾配降下法で地点Oの座標を求める
    func findCoordinatesByGradientDescent(initialPoint: (Float, Float, Float), learningRate: Float, iterations: Int) -> (Float, Float, Float) {
        var point = initialPoint
        
        for _ in 0..<iterations {
            let grad = gradient(at: point)
            point.0 -= learningRate * grad.0
            point.1 -= learningRate * grad.1
            point.2 -= learningRate * grad.2
        }
        
        return point
    }


    // 座標を求める

    
    /*
    func findCoordinates() -> (Float, Float, Float)? {
        // 連立方程式を解くための計算
        let A = 2*(xb - xa)
        let B = 2*(yb - ya)
        let C = 2*(zb - za)
        let D = 2*(xc - xa)
        let E = 2*(yc - ya)
        let F = 2*(zc - za)
        let G = ra*ra - rb*rb - xa*xa - ya*ya - za*za + xb*xb + yb*yb + zb*zb
        let H = ra*ra - rc*rc - xa*xa - ya*ya - za*za + xc*xc + yc*yc + zc*zc
        print(A,B,C,D,E,F,G,H)
        // 行列式の計算
        let det = A*E*F + B*F*D + C*D*E - C*E*D - B*D*F - A*F*E
        print(det)
        if det == 0.0 {
            return nil
        }
        
        // 座標を求める
        let x = (G*E*F + H*B*F + C*D*H - C*E*H - G*B*D - H*F*D) / det
        let y = (A*H*F + G*D*F + B*D*H - B*H*D - G*F*D - A*G*F) / det
        let z = (A*E*H + B*H*D + G*D*E - G*E*D - B*D*H - A*H*E) / det
        print(x,y,z)
        return (x, y, z)
    }*/
}

// MARK: - `NISessionDelegate`.

extension AccessoryDemoViewController: NISessionDelegate {

    func session(_ session: NISession, didGenerateShareableConfigurationData shareableConfigurationData: Data, for object: NINearbyObject) {

        guard object.discoveryToken == configuration?.accessoryDiscoveryToken else { return }
        
        // Prepare to send a message to the accessory.
        var msg = Data([MessageId.configureAndStart.rawValue])
        msg.append(shareableConfigurationData)
        
        let str = msg.map { String(format: "0x%02x, ", $0) }.joined()
        logger.info("Sending shareable configuration bytes: \(str)")
        
        let accessoryName = accessoryMap[object.discoveryToken] ?? "Unknown"
        
        // Send the message to the accessory.
        sendDataToAccessory(msg)
        updateInfoLabel(with: "Sent shareable configuration data to '\(accessoryName)'.")
    }
    
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let accessory = nearbyObjects.first else { return }
        guard let distance = accessory.distance else { return }
        guard let name = accessoryMap[accessory.discoveryToken] else { return }
        if name=="TagA"{
            ra = distance
            self.distanceLabelA.text = String(format: "%0.1f m", distance)
            self.distanceLabelA.sizeToFit()
        }
        else if name=="TagB"{
            rb = distance
            self.distanceLabelB.text = String(format: "%0.1f m", distance)
            self.distanceLabelB.sizeToFit()
        }
        else if name=="TagC"{
            rc = distance
            self.distanceLabelC.text = String(format: "%0.1f m", distance)
            self.distanceLabelC.sizeToFit()
        }
        
        if(dataChannel.TagNumber>2){
            let coordinates = findCoordinatesByGradientDescent(initialPoint: initialPoint, learningRate: learningRate, iterations: iterations)
            let position = String(format: "%0.2f , %0.2f , %0.2f", coordinates.0,coordinates.1,coordinates.2)
            positionLabel.text = position
            print(position)
        }
        
        
        
        /*
        
        if let coordinates = findCoordinates() {
            let position = String(format: "%0.2f,%0.2f,%0.2f", coordinates.0,coordinates.1,coordinates.2)
            positionLabel.text = position
            print(position)
        } else {
            print("解を見つけることができませんでした。")
        }*/
    }
    
    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        // Retry the session only if the peer timed out.
        guard reason == .timeout else { return }
        updateInfoLabel(with: "Session with '\(self.connectedAccessoryName ?? "accessory")' timed out.")
        
        // The session runs with one accessory.
        guard let accessory = nearbyObjects.first else { return }
        
        // Clear the app's accessory state.
        accessoryMap.removeValue(forKey: accessory.discoveryToken)
        
        // Consult helper function to decide whether or not to retry.
        if shouldRetry(accessory) {
            sendDataToAccessory(Data([MessageId.stop.rawValue]))
            sendDataToAccessory(Data([MessageId.initialize.rawValue]))
        }
    }
    
    func sessionWasSuspended(_ session: NISession) {
        updateInfoLabel(with: "Session was suspended.")
        let msg = Data([MessageId.stop.rawValue])
        sendDataToAccessory(msg)
    }
    
    func sessionSuspensionEnded(_ session: NISession) {
        updateInfoLabel(with: "Session suspension ended.")
        // When suspension ends, restart the configuration procedure with the accessory.
        let msg = Data([MessageId.initialize.rawValue])
        sendDataToAccessory(msg)
    }
    
    func session(_ session: NISession, didInvalidateWith error: Error) {
        switch error {
        case NIError.invalidConfiguration:
            // Debug the accessory data to ensure an expected format.
            updateInfoLabel(with: "The accessory configuration data is invalid. Please debug it and try again.")
        case NIError.userDidNotAllow:
            handleUserDidNotAllow()
        default:
            handleSessionInvalidation()
        }
    }
}

// MARK: - Helpers.

extension AccessoryDemoViewController {
    func updateInfoLabel(with text: String) {
        self.infoLabel.text = text
        //self.distanceLabel.sizeToFit()
        logger.info("\(text)")
    }
    
    func sendDataToAccessory(_ data: Data) {
        do {
            try dataChannel.sendData(data)
        } catch {
            updateInfoLabel(with: "Failed to send data to accessory: \(error)")
        }
    }
    
    func handleSessionInvalidation() {
        updateInfoLabel(with: "Session invalidated. Restarting.")
        // Ask the accessory to stop.
        sendDataToAccessory(Data([MessageId.stop.rawValue]))

        // Replace the invalidated session with a new one.
        self.niSessionA = NISession()
        self.niSessionA.delegate = self
        self.niSessionB = NISession()
        self.niSessionB.delegate = self
        self.niSessionC = NISession()
        self.niSessionC.delegate = self

        // Ask the accessory to stop.
        sendDataToAccessory(Data([MessageId.initialize.rawValue]))
    }
    
    func shouldRetry(_ accessory: NINearbyObject) -> Bool {
        if accessoryConnected {
            return true
        }
        return false
    }
    
    func cacheToken(_ token: NIDiscoveryToken, accessoryName: String) {
        accessoryMap[token] = accessoryName
    }
    
    func handleUserDidNotAllow() {
        // Beginning in iOS 15, persistent access state in Settings.
        updateInfoLabel(with: "Nearby Interactions access required. You can change access for NIAccessory in Settings.")
        
        // Create an alert to request the user go to Settings.
        let accessAlert = UIAlertController(title: "Access Required",
                                            message: """
                                            NIAccessory requires access to Nearby Interactions for this sample app.
                                            Use this string to explain to users which functionality will be enabled if they change
                                            Nearby Interactions access in Settings.
                                            """,
                                            preferredStyle: .alert)
        accessAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        accessAlert.addAction(UIAlertAction(title: "Go to Settings", style: .default, handler: {_ in
            // Navigate the user to the app's settings.
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
            }
        }))

        // Preset the access alert.
        present(accessAlert, animated: true, completion: nil)
    }
}

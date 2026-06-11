import SceneKit
import UIKit
import GameplayKit

extension SCNVector3 {
    static func + (l: SCNVector3, r: SCNVector3) -> SCNVector3 {
        SCNVector3(l.x + r.x, l.y + r.y, l.z + r.z)
    }
    static func - (l: SCNVector3, r: SCNVector3) -> SCNVector3 {
        SCNVector3(l.x - r.x, l.y - r.y, l.z - r.z)
    }
    static func * (l: SCNVector3, r: Float) -> SCNVector3 {
        SCNVector3(l.x * r, l.y * r, l.z * r)
    }
    var length: Float { sqrt(x * x + y * y + z * z) }
    func normalized() -> SCNVector3 {
        let len = length
        guard len > 0 else { return self }
        return SCNVector3(x / len, y / len, z / len)
    }
}

final class AirportScene {

    static let tileSize: Float = 2.0
    static let gridSize: Int = 60

    let scene = SCNScene()
    let worldNode = SCNNode()
    let cameraNode = SCNNode()

    private(set) var money: Int = 1000 {
        didSet { onMoneyChange?(money) }
    }
    var onMoneyChange: ((Int) -> Void)?

    private let runwayRow = 50
    private let runwayRowMin = 50
    private let runwayRowMax = 51
    private let runwayColStart = 0
    private let runwayColEnd = 59
    private let runwayExitCol = 28
    private let gates: [(col: Int, row: Int)] = [(27, 35), (32, 35)]
    private var gateOccupied: [Bool] = [false, false]

    private let terminalColMin = 20
    private let terminalColMax = 39
    private let terminalRowMin = 22
    private let terminalRowMax = 32
    private let apronColMin = 22
    private let apronColMax = 37
    private let apronRowMin = 34
    private let apronRowMax = 37
    private let taxiwayColMin = 27
    private let taxiwayColMax = 29
    private let taxiwayRowStart = 38
    private let taxiwayRowEnd = 49
    private let pushbackDepot = (col: 38, row: 36)
    private let pushbackDistance: Float = 5.0

    private var arrivalInterval: TimeInterval = 14.0
    private let planeReward: Int = 50
    private let dockDuration: TimeInterval = 4.0
    private let landDuration: TimeInterval = 2.4
    private let rollDuration: TimeInterval = 4.5
    private let taxiDuration: TimeInterval = 5.5
    private let takeoffDuration: TimeInterval = 3.0
    private let pushbackDuration: TimeInterval = 3.0

    private static let scheduleKey = "plane_schedule"

    init() {
        scene.background.contents = UIColor(red: 0.55, green: 0.78, blue: 0.92, alpha: 1.0)
        scene.fogStartDistance = 200
        scene.fogEndDistance = 400
        scene.fogColor = UIColor(red: 0.62, green: 0.80, blue: 0.92, alpha: 1.0)

        scene.rootNode.addChildNode(worldNode)

        setupCamera()
        setupLighting()
        buildGround()
        buildRunwayApron()
        buildRunway()
        buildTaxiway()
        buildTerminal()
        buildGateMarkers()
        buildRunwayLights()

        startPlaneSchedule()
    }

    func gridToWorld(col: Int, row: Int) -> SCNVector3 {
        SCNVector3(Float(col) * Self.tileSize, 0, Float(row) * Self.tileSize)
    }

    private func setupCamera() {
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = 35
        camera.zNear = 0.1
        camera.zFar = 400
        cameraNode.camera = camera

        let center = gridToWorld(col: 19, row: 25)
        let dist: Float = 120
        let pitch: Float = 35 * .pi / 180
        let yaw: Float = 45 * .pi / 180
        let offset = SCNVector3(
            dist * cos(pitch) * sin(yaw),
            dist * sin(pitch),
            dist * cos(pitch) * cos(yaw)
        )
        cameraNode.position = SCNVector3(center.x + offset.x, center.y + offset.y, center.z + offset.z)
        cameraNode.look(at: center)

        scene.rootNode.addChildNode(cameraNode)
    }

    private func setupLighting() {
        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.color = UIColor(white: 1.0, alpha: 1.0)
        sun.light?.intensity = 900
        sun.light?.castsShadow = true
        sun.light?.shadowMode = .deferred
        sun.light?.shadowMapSize = CGSize(width: 2048, height: 2048)
        sun.light?.shadowSampleCount = 8
        sun.light?.shadowRadius = 4
        sun.light?.shadowColor = UIColor(white: 0, alpha: 0.55)
        sun.light?.orthographicScale = 60
        sun.eulerAngles = SCNVector3(-Float.pi / 3, -Float.pi / 6, 0)
        scene.rootNode.addChildNode(sun)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.color = UIColor(white: 0.55, alpha: 1.0)
        ambient.light?.intensity = 500
        scene.rootNode.addChildNode(ambient)
    }

    private func buildGround() {
        let totalSize = Float(Self.gridSize) * Self.tileSize
        let plane = SCNPlane(width: CGFloat(totalSize), height: CGFloat(totalSize))
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor(red: 0.45, green: 0.72, blue: 0.38, alpha: 1.0)
        mat.roughness.contents = 0.9
        plane.materials = [mat]

        let node = SCNNode(geometry: plane)
        node.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        node.position = SCNVector3(totalSize / 2 - Self.tileSize / 2, 0, totalSize / 2 - Self.tileSize / 2)
        node.castsShadow = false
        worldNode.addChildNode(node)
    }

    private func buildRunwayApron() {
        let centerCol = Float(runwayColStart + runwayColEnd) / 2
        let centerZ = Float(runwayRowMin + runwayRowMax) / 2 * Self.tileSize
        let length = Float(runwayColEnd - runwayColStart + 1) * Self.tileSize + 4
        let width: Float = 6 * Self.tileSize
        let plane = SCNPlane(width: CGFloat(length), height: CGFloat(width))
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor(red: 0.36, green: 0.36, blue: 0.38, alpha: 1.0)
        plane.materials = [mat]
        let node = SCNNode(geometry: plane)
        node.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        node.position = SCNVector3(centerCol * Self.tileSize, 0.01, centerZ)
        worldNode.addChildNode(node)
    }

    private func buildRunway() {
        let length = Float(runwayColEnd - runwayColStart + 1) * Self.tileSize
        let width: Float = 2.5 * Self.tileSize
        let plane = SCNPlane(width: CGFloat(length), height: CGFloat(width))

        let mat = SCNMaterial()
        mat.diffuse.contents = makeRunwayImage(lengthPx: 2000, widthPx: 2000 * CGFloat(width / length))
        mat.diffuse.minificationFilter = .linear
        mat.diffuse.magnificationFilter = .linear
        plane.materials = [mat]

        let centerCol = Float(runwayColStart + runwayColEnd) / 2
        let centerZ = Float(runwayRowMin + runwayRowMax) / 2 * Self.tileSize
        let node = SCNNode(geometry: plane)
        node.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        node.position = SCNVector3(centerCol * Self.tileSize, 0.02, centerZ)
        worldNode.addChildNode(node)
    }

    private func makeRunwayImage(lengthPx: CGFloat, widthPx: CGFloat) -> UIImage {
        let size = CGSize(width: lengthPx, height: widthPx)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            let w = size.width, h = size.height
            UIColor(white: 0.18, alpha: 1.0).setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: size)).fill()

            UIColor.white.setStroke()
            let edge = UIBezierPath()
            edge.lineWidth = max(2, h * 0.025)
            edge.move(to: CGPoint(x: 0, y: h * 0.08))
            edge.addLine(to: CGPoint(x: w, y: h * 0.08))
            edge.move(to: CGPoint(x: 0, y: h * 0.92))
            edge.addLine(to: CGPoint(x: w, y: h * 0.92))
            edge.stroke()

            let dash = UIBezierPath()
            dash.lineWidth = max(2, h * 0.04)
            dash.setLineDash([h * 0.5, h * 0.35], count: 2, phase: 0)
            dash.move(to: CGPoint(x: w * 0.06, y: h / 2))
            dash.addLine(to: CGPoint(x: w * 0.94, y: h / 2))
            dash.stroke()

            UIColor.white.setFill()
            let barCount = 6
            let barWidth = max(3, h * 0.05)
            let barGap = h * 0.10
            let barTop = h * 0.16
            let barHeight = h * 0.68
            for i in 0..<barCount {
                let x1 = w * 0.015 + CGFloat(i) * (barWidth + barGap)
                UIBezierPath(rect: CGRect(x: x1, y: barTop, width: barWidth, height: barHeight)).fill()
                let x2 = w - w * 0.015 - CGFloat(i + 1) * (barWidth + barGap) + barGap
                UIBezierPath(rect: CGRect(x: x2, y: barTop, width: barWidth, height: barHeight)).fill()
            }

            let fs = h * 0.55
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fs, weight: .heavy),
                .foregroundColor: UIColor.white
            ]
            let label1 = NSAttributedString(string: "09", attributes: attrs)
            let s1 = label1.size()
            label1.draw(at: CGPoint(x: w * 0.10, y: (h - s1.height) / 2 - h * 0.02))
            let label2 = NSAttributedString(string: "27", attributes: attrs)
            let s2 = label2.size()
            label2.draw(at: CGPoint(x: w - w * 0.10 - s2.width, y: (h - s2.height) / 2 - h * 0.02))
        }
    }

    private func buildTaxiway() {
        let taxiCenterCol = Float(taxiwayColMin + taxiwayColMax) / 2
        let taxiCenterRow = Float(taxiwayRowStart + taxiwayRowEnd) / 2
        let taxiwayWidth = Float(taxiwayColMax - taxiwayColMin + 1) * Self.tileSize
        let taxiwayLength = Float(taxiwayRowEnd - taxiwayRowStart + 1) * Self.tileSize
        let plane = SCNPlane(width: CGFloat(taxiwayWidth), height: CGFloat(taxiwayLength))
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor(red: 0.50, green: 0.50, blue: 0.52, alpha: 1.0)
        plane.materials = [mat]
        let node = SCNNode(geometry: plane)
        node.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        node.position = SCNVector3(taxiCenterCol * Self.tileSize, 0.015, taxiCenterRow * Self.tileSize)
        worldNode.addChildNode(node)

        let apronCenterCol = Float(apronColMin + apronColMax) / 2
        let apronCenterRow = Float(apronRowMin + apronRowMax) / 2
        let apronWidth = Float(apronColMax - apronColMin + 1) * Self.tileSize
        let apronDepth = Float(apronRowMax - apronRowMin + 1) * Self.tileSize
        let apronPlane = SCNPlane(width: CGFloat(apronWidth), height: CGFloat(apronDepth))
        let apronMat = SCNMaterial()
        apronMat.diffuse.contents = UIColor(red: 0.55, green: 0.55, blue: 0.57, alpha: 1.0)
        apronPlane.materials = [apronMat]
        let apronNode = SCNNode(geometry: apronPlane)
        apronNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        apronNode.position = SCNVector3(apronCenterCol * Self.tileSize, 0.012, apronCenterRow * Self.tileSize)
        worldNode.addChildNode(apronNode)
    }

    private func buildTerminal() {
        let width = Float(terminalColMax - terminalColMin + 1) * Self.tileSize
        let depth = Float(terminalRowMax - terminalRowMin + 1) * Self.tileSize
        let height: Float = 10.0
        let centerCol = Float(terminalColMin + terminalColMax) / 2
        let centerRow = Float(terminalRowMin + terminalRowMax) / 2
        let center = SCNVector3(centerCol * Self.tileSize, 0, centerRow * Self.tileSize)

        let box = SCNBox(width: CGFloat(width), height: CGFloat(height), length: CGFloat(depth), chamferRadius: 0.2)

        let wallTexture = makeWallTexture()
        let wallMat = SCNMaterial()
        wallMat.diffuse.contents = wallTexture
        wallMat.diffuse.wrapS = .repeat
        wallMat.diffuse.wrapT = .repeat

        let roofMat = SCNMaterial()
        roofMat.diffuse.contents = UIColor(red: 0.45, green: 0.28, blue: 0.20, alpha: 1.0)
        roofMat.roughness.contents = 0.85

        let bottomMat = SCNMaterial()
        bottomMat.diffuse.contents = UIColor(red: 0.35, green: 0.30, blue: 0.26, alpha: 1.0)

        box.materials = [wallMat, wallMat, wallMat, wallMat, roofMat, bottomMat]

        let node = SCNNode(geometry: box)
        node.position = SCNVector3(center.x, height / 2, center.z)
        node.castsShadow = true
        worldNode.addChildNode(node)

        let entranceWidth: Float = 2.2
        let entranceHeight: Float = 3.2
        for (i, col) in gates.map({ $0.col }).enumerated() {
            _ = i
            let xPos = Float(col) * Self.tileSize
            let zPos = Float(terminalRowMax) * Self.tileSize + 0.05
            let door = SCNBox(width: CGFloat(entranceWidth), height: CGFloat(entranceHeight),
                              length: 0.1, chamferRadius: 0.05)
            let doorMat = SCNMaterial()
            doorMat.diffuse.contents = UIColor(red: 0.15, green: 0.10, blue: 0.08, alpha: 1.0)
            doorMat.emission.contents = UIColor(red: 0.4, green: 0.3, blue: 0.1, alpha: 1.0)
            door.materials = [doorMat]
            let doorNode = SCNNode(geometry: door)
            doorNode.position = SCNVector3(xPos, entranceHeight / 2, zPos)
            worldNode.addChildNode(doorNode)
        }
    }

    private func makeWallTexture() -> UIImage {
        let size = CGSize(width: 256, height: 192)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            UIColor(red: 0.94, green: 0.88, blue: 0.76, alpha: 1.0).setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: size)).fill()

            let windowCols = 8
            let windowRows = 3
            let cellW = size.width / CGFloat(windowCols)
            let cellH = size.height / CGFloat(windowRows + 1)
            let winW: CGFloat = cellW * 0.55
            let winH: CGFloat = cellH * 0.40
            let litIndices: Set<Int> = [2, 5, 9, 14, 18, 21]
            for r in 0..<windowRows {
                for c in 0..<windowCols {
                    let isLit = litIndices.contains(r * windowCols + c)
                    if isLit {
                        UIColor(red: 1.0, green: 0.85, blue: 0.45, alpha: 1.0).setFill()
                    } else {
                        UIColor(red: 0.32, green: 0.50, blue: 0.80, alpha: 1.0).setFill()
                    }
                    let cx = cellW * (CGFloat(c) + 0.5)
                    let cy = cellH * (CGFloat(r) + 0.7)
                    UIBezierPath(rect: CGRect(x: cx - winW / 2, y: cy - winH / 2, width: winW, height: winH)).fill()
                }
            }
        }
    }

    private func buildGateMarkers() {
        for gate in gates {
            let pos = gridToWorld(col: gate.col, row: gate.row)
            let plane = SCNPlane(width: 1.8, height: 1.8)
            let mat = SCNMaterial()
            mat.diffuse.contents = UIColor(red: 1.0, green: 0.78, blue: 0.10, alpha: 1.0)
            mat.emission.contents = UIColor(red: 0.3, green: 0.20, blue: 0.02, alpha: 1.0)
            plane.materials = [mat]
            let node = SCNNode(geometry: plane)
            node.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
            node.position = SCNVector3(pos.x, 0.025, pos.z)
            worldNode.addChildNode(node)
        }
    }

    private func buildRunwayLights() {
        let start = gridToWorld(col: runwayColStart, row: runwayRow)
        let end = gridToWorld(col: runwayColEnd, row: runwayRow)
        let dx = end.x - start.x
        let length = abs(dx)
        let halfWidth: Float = 1.6 * Self.tileSize / 2 + 0.3

        let lightSpacing: Float = 4.0
        var d: Float = 0
        while d <= length {
            let lx = start.x + d
            addLightPoint(at: SCNVector3(lx, 0.05, start.z - halfWidth), color: UIColor(red: 1, green: 0.92, blue: 0.55, alpha: 1))
            addLightPoint(at: SCNVector3(lx, 0.05, start.z + halfWidth), color: UIColor(red: 1, green: 0.92, blue: 0.55, alpha: 1))
            d += lightSpacing
        }
        for offset in stride(from: -halfWidth, through: halfWidth, by: 0.8) {
            addLightPoint(at: SCNVector3(start.x, 0.05, start.z + offset), color: .systemRed)
            addLightPoint(at: SCNVector3(end.x, 0.05, end.z + offset), color: .systemRed)
        }
    }

    private func addLightPoint(at pos: SCNVector3, color: UIColor) {
        let geom = SCNSphere(radius: 0.18)
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.emission.contents = color
        geom.materials = [mat]
        let node = SCNNode(geometry: geom)
        node.position = pos
        node.castsShadow = false
        worldNode.addChildNode(node)
    }

    private func startPlaneSchedule() {
        worldNode.removeAction(forKey: Self.scheduleKey)
        let initial = SCNAction.wait(duration: 1.5)
        let trigger = SCNAction.run { [weak self] _ in self?.spawnPlaneCycle() }
        let wait = SCNAction.wait(duration: arrivalInterval)
        let loop = SCNAction.repeatForever(SCNAction.sequence([trigger, wait]))
        worldNode.runAction(SCNAction.sequence([initial, loop]), forKey: Self.scheduleKey)
    }

    private func spawnPlaneCycle() {
        guard let gateIndex = (0..<gates.count).first(where: { !gateOccupied[$0] }) else { return }
        gateOccupied[gateIndex] = true
        let gate = gates[gateIndex]

        let touchdown = gridToWorld(col: runwayColEnd, row: runwayRow)
        let runwayExit = gridToWorld(col: runwayExitCol, row: runwayRow)
        let gateWorld = gridToWorld(col: gate.col, row: gate.row)

        let runwayDir = (touchdown - runwayExit).normalized()
        let approachDist: Float = 40
        let altitude: Float = 18
        let approachGround = touchdown + runwayDir * approachDist
        let approachAir = SCNVector3(approachGround.x, altitude, approachGround.z)
        let departGround = touchdown + runwayDir * (approachDist + 8)
        let departAir = SCNVector3(departGround.x, altitude + 8, departGround.z)
        let liftoffAir = SCNVector3(touchdown.x, altitude * 0.35, touchdown.z)

        let plane = Self.makePlane()
        plane.position = approachAir
        plane.look(at: touchdown)
        worldNode.addChildNode(plane)

        let pushbackEnd = SCNVector3(gateWorld.x, 0, gateWorld.z + pushbackDistance)

        let dirToTaxiInitial = (gateWorld - runwayExit).normalized()
        let yawTaxiIn = atan2(dirToTaxiInitial.x, dirToTaxiInitial.z)

        let dirRunwayBack = (runwayExit - pushbackEnd).normalized()
        let yawTaxiOut = atan2(dirRunwayBack.x, dirRunwayBack.z)

        let dirTakeoff = (touchdown - runwayExit).normalized()
        let yawTakeoff = atan2(dirTakeoff.x, dirTakeoff.z)

        let yawLanding = atan2((touchdown - approachAir).x, (touchdown - approachAir).z)

        let land = SCNAction.move(to: touchdown, duration: landDuration)
        land.timingMode = .easeIn
        let roll = SCNAction.move(to: runwayExit, duration: rollDuration)
        roll.timingMode = .easeOut

        let alignTaxiIn = SCNAction.rotateTo(x: 0, y: CGFloat(yawTaxiIn), z: 0, duration: 0.7, usesShortestUnitArc: true)
        let taxiIn = SCNAction.move(to: gateWorld, duration: taxiDuration)
        taxiIn.timingMode = .easeInEaseOut

        let spawnTruck = SCNAction.run { [weak self] _ in
            self?.animatePushbackTruck(forPlaneAt: gateWorld)
        }
        let dockWait = SCNAction.wait(duration: dockDuration)

        let pushPlane = SCNAction.move(to: pushbackEnd, duration: pushbackDuration)
        pushPlane.timingMode = .easeInEaseOut

        let alignTaxiOut = SCNAction.rotateTo(x: 0, y: CGFloat(yawTaxiOut), z: 0, duration: 1.0, usesShortestUnitArc: true)
        let taxiOut = SCNAction.move(to: runwayExit, duration: taxiDuration)
        taxiOut.timingMode = .easeInEaseOut

        let alignTakeoff = SCNAction.rotateTo(x: 0, y: CGFloat(yawTakeoff), z: 0, duration: 0.9, usesShortestUnitArc: true)
        let takeoff = SCNAction.move(to: liftoffAir, duration: takeoffDuration)
        takeoff.timingMode = .easeIn
        let depart = SCNAction.move(to: departAir, duration: 1.4)
        depart.timingMode = .easeOut

        let fade = SCNAction.fadeOut(duration: 0.4)

        let cleanup = SCNAction.run { [weak self] _ in
            guard let self = self else { return }
            self.gateOccupied[gateIndex] = false
            self.money += self.planeReward
        }

        let initialYawAction = SCNAction.rotateTo(x: 0, y: CGFloat(yawLanding), z: 0, duration: 0.01, usesShortestUnitArc: false)
        let remove = SCNAction.removeFromParentNode()

        plane.runAction(SCNAction.sequence([
            initialYawAction,
            land, roll,
            alignTaxiIn, taxiIn,
            spawnTruck,
            dockWait,
            pushPlane,
            alignTaxiOut, taxiOut,
            alignTakeoff, takeoff,
            depart,
            fade,
            cleanup,
            remove
        ]))
    }

    private func animatePushbackTruck(forPlaneAt gate: SCNVector3) {
        let truck = Self.makePushbackTruck()
        let depotPos = gridToWorld(col: pushbackDepot.col, row: pushbackDepot.row)
        truck.position = depotPos

        let toPlaneVec = SCNVector3(gate.x - depotPos.x, 0, gate.z - depotPos.z)
        truck.eulerAngles.y = atan2(toPlaneVec.x, toPlaneVec.z)
        worldNode.addChildNode(truck)

        let nosePos = SCNVector3(gate.x, 0, gate.z - 2.0)
        let toPlane = SCNAction.move(to: nosePos, duration: 1.5)
        toPlane.timingMode = .easeInEaseOut

        let alignNose = SCNAction.rotateTo(x: 0, y: CGFloat.pi, z: 0, duration: 0.4, usesShortestUnitArc: true)

        let waitAtPlane = SCNAction.wait(duration: max(0, dockDuration - 1.5 - 0.4))

        let truckPushEnd = SCNVector3(gate.x, 0, gate.z + pushbackDistance - 2.0)
        let truckPush = SCNAction.move(to: truckPushEnd, duration: pushbackDuration)
        truckPush.timingMode = .easeInEaseOut

        let toDepotVec = SCNVector3(depotPos.x - truckPushEnd.x, 0, depotPos.z - truckPushEnd.z)
        let yawHome = atan2(toDepotVec.x, toDepotVec.z)
        let alignHome = SCNAction.rotateTo(x: 0, y: CGFloat(yawHome), z: 0, duration: 0.5, usesShortestUnitArc: true)

        let goHome = SCNAction.move(to: depotPos, duration: 1.8)
        goHome.timingMode = .easeInEaseOut
        let remove = SCNAction.removeFromParentNode()

        truck.runAction(SCNAction.sequence([
            toPlane, alignNose, waitAtPlane, truckPush, alignHome, goHome, remove
        ]))
    }

    private static let a320Template: SCNNode? = {
        guard let url = Bundle.main.url(forResource: "White_Airbus_A320-200", withExtension: "usdz"),
              let scene = try? SCNScene(url: url, options: nil) else {
            return nil
        }
        let container = SCNNode()
        for child in scene.rootNode.childNodes {
            container.addChildNode(child.clone())
        }
        return container
    }()

    private static func makePlane() -> SCNNode {
        let plane = SCNNode()

        if let template = a320Template?.clone() {
            let bbox = template.boundingBox
            let sizeX = bbox.max.x - bbox.min.x
            let sizeY = bbox.max.y - bbox.min.y
            let sizeZ = bbox.max.z - bbox.min.z
            let longest = max(sizeX, sizeY, sizeZ)
            let targetLength: Float = 10
            let scale = targetLength / longest
            template.scale = SCNVector3(scale, scale, scale)
            template.position = SCNVector3(
                -(bbox.min.x + bbox.max.x) / 2 * scale,
                -bbox.min.y * scale,
                -(bbox.min.z + bbox.max.z) / 2 * scale
            )
            applyCastsShadow(to: template)
            plane.addChildNode(template)
        } else {
            let fallback = SCNBox(width: 18, height: 2, length: 14, chamferRadius: 0.5)
            fallback.firstMaterial?.diffuse.contents = UIColor.white
            let node = SCNNode(geometry: fallback)
            node.castsShadow = true
            plane.addChildNode(node)
        }

        return plane
    }

    private static func applyCastsShadow(to node: SCNNode) {
        node.castsShadow = true
        for child in node.childNodes {
            applyCastsShadow(to: child)
        }
    }

    private static func makePushbackTruck() -> SCNNode {
        let truck = SCNNode()

        let body = SCNBox(width: 2.2, height: 0.9, length: 1.4, chamferRadius: 0.15)
        let bodyMat = SCNMaterial()
        bodyMat.diffuse.contents = UIColor(red: 1.0, green: 0.82, blue: 0.10, alpha: 1.0)
        bodyMat.roughness.contents = 0.4
        body.materials = [bodyMat]
        let bodyNode = SCNNode(geometry: body)
        bodyNode.position = SCNVector3(0, 0.65, 0)
        bodyNode.castsShadow = true
        truck.addChildNode(bodyNode)

        let cabin = SCNBox(width: 1.0, height: 0.55, length: 1.2, chamferRadius: 0.1)
        let cabinMat = SCNMaterial()
        cabinMat.diffuse.contents = UIColor(red: 0.18, green: 0.25, blue: 0.45, alpha: 1.0)
        cabinMat.metalness.contents = 0.6
        cabin.materials = [cabinMat]
        let cabinNode = SCNNode(geometry: cabin)
        cabinNode.position = SCNVector3(-0.4, 1.35, 0)
        cabinNode.castsShadow = true
        truck.addChildNode(cabinNode)

        let wheelGeom = SCNCylinder(radius: 0.32, height: 0.22)
        let wheelMat = SCNMaterial()
        wheelMat.diffuse.contents = UIColor(white: 0.12, alpha: 1.0)
        wheelGeom.materials = [wheelMat]
        for x in [-0.7, 0.7] {
            for z in [-0.55, 0.55] {
                let wheel = SCNNode(geometry: wheelGeom)
                wheel.position = SCNVector3(Float(x), 0.32, Float(z))
                wheel.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
                wheel.castsShadow = true
                truck.addChildNode(wheel)
            }
        }

        let towBar = SCNCylinder(radius: 0.06, height: 1.4)
        let towMat = SCNMaterial()
        towMat.diffuse.contents = UIColor(white: 0.25, alpha: 1.0)
        towBar.materials = [towMat]
        let towNode = SCNNode(geometry: towBar)
        towNode.position = SCNVector3(1.7, 0.55, 0)
        towNode.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
        towNode.castsShadow = true
        truck.addChildNode(towNode)

        return truck
    }

    func buyFrequencyUpgrade() -> Bool {
        let cost = 300
        guard money >= cost else { return false }
        money -= cost
        arrivalInterval = max(6.0, arrivalInterval - 4.0)
        startPlaneSchedule()
        return true
    }
}

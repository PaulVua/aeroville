import UIKit
import SceneKit

final class GameViewController: UIViewController {

    private var airport: AirportScene!
    private var scnView: SCNView!
    private var moneyLabel: UILabel!
    private var upgradeButton: UIButton!
    private var resetButton: UIButton!
    private var takeoffButton: UIButton!
    private var selectedPlane: SCNNode?

    private var cameraTarget = SCNVector3(0, 0, 0)
    private var cameraDistance: Float = 180
    private var cameraAzimuth: Float = .pi / 4
    private var cameraElevation: Float = .pi / 6

    private let defaultAzimuth: Float = .pi / 4
    private let defaultElevation: Float = .pi / 6
    private let defaultOrthoScale: Double = 55
    private let minElevation: Float = 10 * .pi / 180
    private let maxElevation: Float = 80 * .pi / 180
    private let minOrthoScale: Double = 8
    private let maxOrthoScale: Double = 120

    override func loadView() {
        let view = SCNView()
        view.backgroundColor = UIColor(red: 0.55, green: 0.78, blue: 0.92, alpha: 1.0)
        view.antialiasingMode = .multisampling4X
        self.view = view
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        scnView = self.view as? SCNView

        airport = AirportScene()
        scnView.scene = airport.scene
        scnView.pointOfView = airport.cameraNode
        scnView.allowsCameraControl = false
        scnView.showsStatistics = false

        airport.onMoneyChange = { [weak self] money in
            self?.updateMoney(money)
        }

        cameraTarget = airport.gridToWorld(col: 30, row: 42)
        applyCamera()

        installMoneyLabel()
        installUpgradeButton()
        installResetButton()
        installTakeoffButton()
        installGestures()
        updateMoney(airport.money)
    }

    private func installTakeoffButton() {
        var config = UIButton.Configuration.filled()
        config.title = "🛫  Autoriser décollage"
        config.baseBackgroundColor = UIColor(red: 0.9, green: 0.3, blue: 0.15, alpha: 1.0)
        config.cornerStyle = .large
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 22, bottom: 14, trailing: 22)
        var attr = AttributedString(config.title ?? "")
        attr.font = .systemFont(ofSize: 18, weight: .bold)
        config.attributedTitle = attr
        takeoffButton = UIButton(configuration: config, primaryAction: UIAction { [weak self] _ in
            self?.handleTakeoff()
        })
        takeoffButton.translatesAutoresizingMaskIntoConstraints = false
        takeoffButton.isHidden = true
        view.addSubview(takeoffButton)
        NSLayoutConstraint.activate([
            takeoffButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            takeoffButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
        ])
    }

    private func handleTakeoff() {
        guard let plane = selectedPlane else { return }
        if airport.grantTakeoff(for: plane) {
            selectedPlane = nil
            takeoffButton.isHidden = true
        } else {
            let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
            shake.values = [-8, 8, -6, 6, -3, 3, 0]
            shake.duration = 0.35
            takeoffButton.layer.add(shake, forKey: "shake")
        }
    }

    private func findPlaneRoot(from node: SCNNode) -> SCNNode? {
        var current: SCNNode? = node
        while let n = current {
            if n.name == "plane" { return n }
            current = n.parent
        }
        return nil
    }

    private func applyCamera() {
        let cosE = cos(cameraElevation)
        let sinE = sin(cameraElevation)
        let sinA = sin(cameraAzimuth)
        let cosA = cos(cameraAzimuth)
        airport.cameraNode.position = SCNVector3(
            cameraTarget.x + cameraDistance * cosE * sinA,
            cameraTarget.y + cameraDistance * sinE,
            cameraTarget.z + cameraDistance * cosE * cosA
        )
        airport.cameraNode.look(at: cameraTarget)
    }

    private func installMoneyLabel() {
        moneyLabel = UILabel()
        moneyLabel.font = .systemFont(ofSize: 26, weight: .bold)
        moneyLabel.textColor = .white
        moneyLabel.layer.shadowColor = UIColor.black.cgColor
        moneyLabel.layer.shadowRadius = 3
        moneyLabel.layer.shadowOpacity = 0.9
        moneyLabel.layer.shadowOffset = .zero
        moneyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(moneyLabel)
        NSLayoutConstraint.activate([
            moneyLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 18),
            moneyLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
        ])
    }

    private func installUpgradeButton() {
        var config = UIButton.Configuration.filled()
        config.title = "Améliorer fréquence — 300€"
        config.baseBackgroundColor = UIColor(red: 0.20, green: 0.65, blue: 0.35, alpha: 1.0)
        config.cornerStyle = .large
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 22, bottom: 14, trailing: 22)
        var attrTitle = AttributedString(config.title ?? "")
        attrTitle.font = .systemFont(ofSize: 16, weight: .semibold)
        config.attributedTitle = attrTitle
        upgradeButton = UIButton(configuration: config, primaryAction: UIAction { [weak self] _ in
            self?.handleUpgrade()
        })
        upgradeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(upgradeButton)
        NSLayoutConstraint.activate([
            upgradeButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            upgradeButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
        ])
    }

    private func installResetButton() {
        var config = UIButton.Configuration.gray()
        config.title = "↺ Vue"
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
        var attrTitle = AttributedString(config.title ?? "")
        attrTitle.font = .systemFont(ofSize: 14, weight: .semibold)
        config.attributedTitle = attrTitle
        resetButton = UIButton(configuration: config, primaryAction: UIAction { [weak self] _ in
            self?.resetCamera()
        })
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(resetButton)
        NSLayoutConstraint.activate([
            resetButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            resetButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 18),
        ])
    }

    private func handleUpgrade() {
        if airport.buyFrequencyUpgrade() {
            var config = upgradeButton.configuration
            config?.title = "Fréquence améliorée ✓"
            var attr = AttributedString(config?.title ?? "")
            attr.font = .systemFont(ofSize: 16, weight: .semibold)
            config?.attributedTitle = attr
            config?.baseBackgroundColor = .systemGray
            upgradeButton.configuration = config
            upgradeButton.isEnabled = false
        }
    }

    private func resetCamera() {
        cameraTarget = airport.gridToWorld(col: 30, row: 42)
        cameraAzimuth = defaultAzimuth
        cameraElevation = defaultElevation
        airport.cameraNode.camera?.orthographicScale = defaultOrthoScale
        applyCamera()
    }

    private func updateMoney(_ money: Int) {
        moneyLabel.text = "Caisse : \(money) €"
    }

    private func installGestures() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1
        let twoFingerPan = UIPanGestureRecognizer(target: self, action: #selector(handleTwoFingerPan(_:)))
        twoFingerPan.minimumNumberOfTouches = 2
        twoFingerPan.maximumNumberOfTouches = 2
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        let rotate = UIRotationGestureRecognizer(target: self, action: #selector(handleRotate(_:)))
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap(_:)))
        singleTap.numberOfTapsRequired = 1
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        singleTap.require(toFail: doubleTap)
        scnView.addGestureRecognizer(pan)
        scnView.addGestureRecognizer(twoFingerPan)
        scnView.addGestureRecognizer(pinch)
        scnView.addGestureRecognizer(rotate)
        scnView.addGestureRecognizer(singleTap)
        scnView.addGestureRecognizer(doubleTap)
        pinch.delegate = self
        rotate.delegate = self
        twoFingerPan.delegate = self
        singleTap.delegate = self
    }

    @objc private func handleSingleTap(_ recognizer: UITapGestureRecognizer) {
        let point = recognizer.location(in: scnView)
        let hits = scnView.hitTest(point, options: [SCNHitTestOption.boundingBoxOnly: false])
        for hit in hits {
            if let plane = findPlaneRoot(from: hit.node), airport.isPlaneWaiting(plane) {
                selectedPlane = plane
                takeoffButton.isHidden = false
                return
            }
        }
        selectedPlane = nil
        takeoffButton.isHidden = true
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard let cam = airport.cameraNode.camera else { return }
        let t = recognizer.translation(in: recognizer.view)
        let speed = Float(cam.orthographicScale) * 0.003
        let sinA = sin(cameraAzimuth)
        let cosA = cos(cameraAzimuth)
        let dx = Float(t.x) * speed
        let dy = Float(t.y) * speed
        cameraTarget.x -= cosA * dx + sinA * dy
        cameraTarget.z += sinA * dx - cosA * dy
        clampCameraTarget()
        applyCamera()
        recognizer.setTranslation(.zero, in: recognizer.view)
    }

    @objc private func handleTwoFingerPan(_ recognizer: UIPanGestureRecognizer) {
        let t = recognizer.translation(in: recognizer.view)
        let elevDelta = -Float(t.y) * 0.006
        cameraElevation = max(minElevation, min(maxElevation, cameraElevation + elevDelta))
        applyCamera()
        recognizer.setTranslation(.zero, in: recognizer.view)
    }

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        guard let cam = airport.cameraNode.camera else { return }
        let newScale = cam.orthographicScale / Double(recognizer.scale)
        cam.orthographicScale = max(minOrthoScale, min(maxOrthoScale, newScale))
        recognizer.scale = 1.0
    }

    @objc private func handleRotate(_ recognizer: UIRotationGestureRecognizer) {
        cameraAzimuth -= Float(recognizer.rotation)
        applyCamera()
        recognizer.rotation = 0
    }

    @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        resetCamera()
    }

    private func clampCameraTarget() {
        let total = Float(AirportScene.gridSize) * AirportScene.tileSize
        cameraTarget.x = max(-20, min(total + 20, cameraTarget.x))
        cameraTarget.z = max(-20, min(total + 20, cameraTarget.z))
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return [.landscapeLeft, .landscapeRight]
    }

    override var prefersStatusBarHidden: Bool { true }
}

extension GameViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        return true
    }
}

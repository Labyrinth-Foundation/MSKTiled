import SpriteKit
import GameplayKit

open class MSKTiledMapScene: SKScene {

    public let cameraNode: MSKTiledCameraNode

    public let layers: [SKTileMapNode]
    public let tileGroups: [SKTileGroup]
    public let tiledObjectGroups: [MSKTiledObjectGroup]?
    public let zPositionPerNamedLayer: [String: Int]

    public let mapNode = SKNode()
    private let baseTileMapNode: SKTileMapNode
    private var pathGraph: GKGridGraph<GKGridGraphNode>?

    public init(layers: [SKTileMapNode],
                tileGroups: [SKTileGroup],
                tiledObjectGroups: [MSKTiledObjectGroup]?,
                size: CGSize,
                minimumCameraScale: CGFloat,
                maximumCameraScale: CGFloat?,
                zPositionPerNamedLayer: [String: Int]) {
        self.layers = layers
        self.tileGroups = tileGroups
        self.tiledObjectGroups = tiledObjectGroups

        guard let firstLayer = layers.first else {
            fatalError("No layers provided")
        }
        baseTileMapNode = firstLayer

        let maximumScalePossible = min(firstLayer.frame.width/size.width,
                                  firstLayer.frame.height/size.height) * 0.999
        let maximumScaleToInject: CGFloat
        if let maximumCameraScale = maximumCameraScale {
            if maximumCameraScale > maximumScalePossible {
                fatalError("Maxzoom provided impossible, max possible zoom: \(maximumScalePossible).")
            }
            maximumScaleToInject = maximumCameraScale
        } else {
            maximumScaleToInject = maximumScalePossible
        }
        var minimumCameraScaleToInject = minimumCameraScale
        if maximumScaleToInject < minimumCameraScaleToInject {
            minimumCameraScaleToInject = maximumScaleToInject
            log(logLevel: .warning, message: "minimumCameraScale is greater than maximumCameraScale")
        }

        self.cameraNode = MSKTiledCameraNode(minimumCameraScale: minimumCameraScaleToInject,
                                             maximumCameraScale: maximumScaleToInject)
        self.zPositionPerNamedLayer = zPositionPerNamedLayer

        super.init(size: size)
        camera = cameraNode
        addChild(cameraNode)
    }

    public init(size: CGSize,
                tiledMapName: String,
                minimumCameraScale: CGFloat,
                maximumCameraScale: CGFloat?,
                zPositionPerNamedLayer: [String: Int],
                addingCustomTileGroups: [SKTileGroup]? = nil) {
        let parser = MSKTiledMapParser()
        parser.loadTilemap(filename: tiledMapName, addingCustomTileGroups: addingCustomTileGroups)
        let parsed = parser.getTileMapNodes()
        layers = parsed.layers
        tileGroups = parsed.tileGroups
        tiledObjectGroups = parsed.tiledObjectGroups

        guard let firstLayer = layers.first else {
            fatalError("No layers parsed from map: \(tiledMapName)")
        }
        baseTileMapNode = firstLayer

        let maximumScalePossible = min(firstLayer.frame.width/size.width,
                                  firstLayer.frame.height/size.height) * 0.999
        let maximumScaleToInject: CGFloat
        if let maximumCameraScale = maximumCameraScale {
            if maximumCameraScale > maximumScalePossible {
                fatalError("Maxzoom provided impossible, max possible zoom: \(maximumScalePossible).")
            }
            maximumScaleToInject = maximumCameraScale
        } else {
            maximumScaleToInject = maximumScalePossible
        }
        var minimumCameraScaleToInject = minimumCameraScale
        if maximumScaleToInject < minimumCameraScaleToInject {
            minimumCameraScaleToInject = maximumScaleToInject
            log(logLevel: .warning, message: "minimumCameraScale is greater than maximumCameraScale")
        }

        self.cameraNode = MSKTiledCameraNode(minimumCameraScale: minimumCameraScaleToInject,
                                             maximumCameraScale: maximumScaleToInject)
        self.zPositionPerNamedLayer = zPositionPerNamedLayer

        super.init(size: size)
        camera = cameraNode
        addChild(cameraNode)
    }

    open override func didMove(to view: SKView) {
        super.didMove(to: view)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)

        addChild(mapNode)
        for layer in layers {
            var found = false
            for zPositionLayer in zPositionPerNamedLayer where zPositionLayer.key == layer.name {
                layer.zPosition = CGFloat(zPositionLayer.value)
                found = true
            }
            if !found {
                log(logLevel: .warning, message: "No z-position provided for layer with name \(layer.name ?? "undefined")")
            }
            mapNode.addChild(layer)
        }

        setCameraConstraints()
    }

    public func updatePathGraphUsing(layer: SKTileMapNode, obstacleProperty: String, diagonalsAllowed: Bool) {
        pathGraph = GKGridGraph(fromGridStartingAt: vector_int2(0, 0),
                                width: Int32(layer.numberOfColumns),
                                height: Int32(layer.numberOfRows),
                                diagonalsAllowed: diagonalsAllowed)
        guard let pathGraph else {
            return
        }
        var obstacles = [GKGridGraphNode]()
        for column in 0..<layer.numberOfColumns {
            for row in 0..<layer.numberOfRows {
                if let properties = getPropertiesForTileInLayer(layer: layer, tile: .init(column: column, row: row)),
                   let isObstacle = properties[obstacleProperty] as? Bool,
                   isObstacle {
                    obstacles.append(pathGraph.node(atGridPosition: vector_int2(Int32(column), Int32(row)))!)
                }
            }
        }
    }

    public func updatePathGraphUsing(layer: SKTileMapNode, obstacleProperty: String, diagonalsAllowed: Bool, removingTiles: [MSKTiledTile]) {
        pathGraph = GKGridGraph(fromGridStartingAt: vector_int2(0, 0),
                                width: Int32(layer.numberOfColumns),
                                height: Int32(layer.numberOfRows),
                                diagonalsAllowed: diagonalsAllowed)
        guard let pathGraph else {
            return
        }
        var obstacles = [GKGridGraphNode]()
        for column in 0..<layer.numberOfColumns {
            for row in 0..<layer.numberOfRows {
                if removingTiles.contains(.init(column: column, row: row)) {
                    obstacles.append(pathGraph.node(atGridPosition: vector_int2(Int32(column), Int32(row)))!)
                } else if let properties = getPropertiesForTileInLayer(layer: layer, tile: .init(column: column, row: row)),
                          let isObstacle = properties[obstacleProperty] as? Bool,
                          isObstacle {
                    obstacles.append(pathGraph.node(atGridPosition: vector_int2(Int32(column), Int32(row)))!)
                }
            }
        }
        pathGraph.remove(obstacles)
    }

    public func updatePathGraphUsing(layer: SKTileMapNode, diagonalsAllowed: Bool) {
        pathGraph = GKGridGraph(fromGridStartingAt: vector_int2(0, 0),
                                width: Int32(layer.numberOfColumns),
                                height: Int32(layer.numberOfRows),
                                diagonalsAllowed: diagonalsAllowed)
        guard let pathGraph else {
            return
        }
        for column in 0..<layer.numberOfColumns {
            for row in 0..<layer.numberOfRows {
                if layer.tileGroup(atColumn: column, row: row) != nil {
                    let node = pathGraph.node(atGridPosition: vector_int2(Int32(column), Int32(row)))!
                    node.removeConnections(to: node.connectedNodes, bidirectional: false)
                }
            }
        }
    }

    public func getPath(fromTile: MSKTiledTile, toTile: MSKTiledTile) -> [MSKTiledTile]? {
        if !isValidTile(tile: fromTile) {
            log(logLevel: .warning, message: "Invalid tile provided as start for path")
        } else if !isValidTile(tile: toTile) {
            log(logLevel: .warning, message: "Invalid tile provided as end for path")
        }
        guard let pathGraph = pathGraph else {
            log(logLevel: .warning, message: "Pathgraph has not been initialized yet")
            return nil
        }
        guard let startNode = pathGraph.node(atGridPosition: vector_int2(Int32(fromTile.column), Int32(fromTile.row))) else {
            log(logLevel: .warning, message: "Invalid start position for finding a path")
            return nil
        }
        guard let endNode = pathGraph.node(atGridPosition: vector_int2(Int32(toTile.column), Int32(toTile.row))) else {
            log(logLevel: .warning, message: "Invalid end position for finding a path")
            return nil
        }
        let foundPath = pathGraph.findPath(from: startNode, to: endNode)
        if foundPath.isEmpty {
            log(logLevel: .warning, message: "Path could not be determined")
            return nil
        }
        var points = [MSKTiledTile]()
        foundPath.forEach { pathNode in
            if let graphNode = pathNode as? GKGridGraphNode {
                points.append(.init(column: Int(graphNode.gridPosition.x),
                                    row: Int(graphNode.gridPosition.y)))
            }
        }
        return points
    }

    public func isValidTile(tile: MSKTiledTile) -> Bool {
        if tile.row < 0 || tile.column < 0 {
            return false
        }
        return tile.row <= baseTileMapNode.numberOfRows-1 || tile.column <= baseTileMapNode.numberOfColumns-1
    }

    public func isValidPathTile(tile: MSKTiledTile) -> Bool {
        guard isValidTile(tile: tile) else {
            return false
        }
        guard let node = pathGraph?.node(atGridPosition: .init(Int32(tile.column), Int32(tile.row))) else {
            return false
        }
        return node.connectedNodes.count > 0
    }

    open override func willMove(from view: SKView) {
        super.willMove(from: view)
        pathGraph = nil
    }

    public func getTileFromPositionInScene(position: CGPoint) -> MSKTiledTile? {
        let pos = convert(position, to: baseTileMapNode)
        let column = baseTileMapNode.tileColumnIndex(fromPosition: pos)
        let row = baseTileMapNode.tileRowIndex(fromPosition: pos)
        let tile = MSKTiledTile(column: column, row: row)
        return isValidTile(tile: tile) ? tile : nil
    }

    public func getLayer(name: String) -> SKTileMapNode? {
        if let layer = layers.first(where: { $0.name == name }) {
            return layer
        }
        return nil
    }

    public func setCameraTo(cameraPosition: CGPoint) {
        cameraNode.position = cameraPosition
        setCameraConstraints()
    }

    public func scaleTo(scale: CGFloat) {
        cameraNode.setScale(scale)
        setCameraConstraints()
    }

    public func getPositionInSceneFromTile(tile: MSKTiledTile) -> CGPoint {
        return baseTileMapNode.centerOfTile(atColumn: tile.column, row: tile.row)
    }

    public func getPositionsInSceneFromTiles(tiles: [MSKTiledTile]) -> [CGPoint] {
        var points = [CGPoint]()
        for tile in tiles {
            points.append(getPositionInSceneFromTile(tile: tile))
        }
        return points
    }

    public func replaceTileGroupForTile(layer: SKTileMapNode, tile: MSKTiledTile, tileGroup: SKTileGroup) {
        layer.setTileGroup(tileGroup, forColumn: tile.column, row: tile.row)
    }

    public func removeTileGroupForTile(layer: SKTileMapNode, tile: MSKTiledTile, tileGroup: SKTileGroup) {
        layer.setTileGroup(nil, forColumn: tile.column, row: tile.row)
    }

    public func getPropertiesForTileInLayer(layer: SKTileMapNode, tile: MSKTiledTile) -> NSMutableDictionary? {
        return layer.tileDefinition(atColumn: tile.column, row: tile.row)?.userData
    }

    private func setCameraConstraints() {
        return;
        let scaledSize = CGSize(width: size.width * cameraNode.xScale, height: size.height * cameraNode.yScale)
        let contentBounds = baseTileMapNode.frame
        let xInset = scaledSize.width / 2
        let yInset = scaledSize.height / 2

        let insetContentRect = contentBounds.insetBy(dx: xInset, dy: yInset)
        let xRange = SKRange(lowerLimit: insetContentRect.minX, upperLimit: insetContentRect.maxX)
        let yRange = SKRange(lowerLimit: insetContentRect.minY, upperLimit: insetContentRect.maxY)

        let levelEdgeConstraint = SKConstraint.positionX(xRange, y: yRange)
        levelEdgeConstraint.referenceNode = mapNode

        cameraNode.constraints = [levelEdgeConstraint]
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

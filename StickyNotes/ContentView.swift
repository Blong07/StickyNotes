import SwiftUI
import RealityKit

@main
struct StickyNotesApp: App {
    var body: some SwiftUI.Scene {
        WindowGroup {
            ContentView()
        }
        // Use default window style for better visibility
        .defaultSize(CGSize(width: 800, height: 600))
    }
}

// Model for a sticky note
struct StickyNote: Identifiable {
    let id = UUID()
    var text: String
    var position: SIMD3<Float>
    var entity: ModelEntity?
}

struct ContentView: View {
    @State private var stickyNotes: [StickyNote] = []
    @State private var showCreateNote = false
    @State private var newNoteText = ""
    @State private var selectedNote: StickyNote?
    
    var body: some View {
        ZStack {
            // Background color
            Color.gray.opacity(0.1)
                .ignoresSafeArea()
            
            // 3D RealityKit view
            RealityView { content in
                // Add a light to make things visible
                let light = DirectionalLight()
                light.light.intensity = 1000
                content.add(light)
            } update: { content in
                updateStickyNotes(content: content)
            }
            
            // UI Controls overlay
            VStack {
                // Title at top
                Text("Sticky Notes 3D")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.top)
                
                Spacer()
                
                if showCreateNote {
                    createNoteView
                        .padding()
                }
                
                HStack {
                    Button("Create Sticky Note") {
                        showCreateNote = true
                    }
                    .font(.title3)
                    .padding()
                    .background(.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    if !stickyNotes.isEmpty {
                        Button("Clear All") {
                            stickyNotes.removeAll()
                        }
                        .font(.title3)
                        .padding()
                        .background(.red)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
        }
    }
    
    var createNoteView: some View {
        VStack(spacing: 12) {
            Text("New Sticky Note")
                .font(.headline)
                .padding(.top)
            
            TextField("Enter your note...", text: $newNoteText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(4...8)
                .frame(width: 300)
                .padding(.horizontal)
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    newNoteText = ""
                    showCreateNote = false
                }
                .buttonStyle(.bordered)
                
                Button("Create") {
                    createStickyNote()
                }
                .buttonStyle(.borderedProminent)
                .disabled(newNoteText.isEmpty)
            }
            .padding(.bottom)
        }
        .frame(width: 350)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    func createStickyNote() {
        // Generate position within the window bounds
        let randomX = Float.random(in: -0.3...0.3)
        let randomY = Float.random(in: -0.2...0.2)
        let randomZ = Float.random(in: -0.2...0.1)
        
        let newNote = StickyNote(
            text: newNoteText,
            position: SIMD3<Float>(randomX, randomY, randomZ)
        )
        
        stickyNotes.append(newNote)
        newNoteText = ""
        showCreateNote = false
    }
    
    func updateStickyNotes(content: RealityViewContent) {
        // Only process entities that we've created
        let noteEntities = content.entities.compactMap { entity -> ModelEntity? in
            if let modelEntity = entity as? ModelEntity,
               entity.components.has(StickyNoteComponent.self) {
                return modelEntity
            }
            return nil
        }
        
        // Remove orphaned note entities
        let entitiesToRemove = noteEntities.filter { entity in
            !stickyNotes.contains(where: { $0.entity === entity })
        }
        
        entitiesToRemove.forEach { entity in
            entity.removeFromParent()
        }
        
        // Add or update sticky note entities
        for index in stickyNotes.indices {
            if stickyNotes[index].entity == nil {
                let noteEntity = createStickyNoteEntity(note: stickyNotes[index])
                stickyNotes[index].entity = noteEntity
                content.add(noteEntity)
            }
        }
    }
    
    func createStickyNoteEntity(note: StickyNote) -> ModelEntity {
        // Create the sticky note mesh (smaller for window)
        let mesh = MeshResource.generateBox(width: 0.15, height: 0.15, depth: 0.005)
        
        // Create material with yellow color
        var material = UnlitMaterial()
        material.color = .init(tint: .yellow)
        
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.position = note.position
        
        // Add components for interaction
        entity.components.set(InputTargetComponent())
        entity.components.set(CollisionComponent(shapes: [.generateBox(width: 0.15, height: 0.15, depth: 0.005)]))
        entity.components.set(HoverEffectComponent())
        entity.components.set(StickyNoteComponent(noteId: note.id))
        
        // Add text as a child entity
        if let textEntity = createTextEntity(text: note.text) {
            textEntity.position = [0, 0, 0.003]
            entity.addChild(textEntity)
        }
        
        return entity
    }
    
    func createTextEntity(text: String) -> ModelEntity? {
        let textMesh = MeshResource.generateText(
            text,
            extrusionDepth: 0.001,
            font: .systemFont(ofSize: 0.01),
            containerFrame: CGRect(x: -0.065, y: -0.065, width: 0.13, height: 0.13),
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )
        
        var textMaterial = UnlitMaterial()
        textMaterial.color = .init(tint: .black)
        
        let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])
        return textEntity
    }
}

// Components
struct HoverEffectComponent: Component {
    var isHovered: Bool = false
}

struct StickyNoteComponent: Component {
    let noteId: UUID
}

// Gesture handling extension
extension ContentView {
    func addGestures(to entity: ModelEntity) -> some View {
        RealityView { content in
            // This is where you'd add gesture recognizers
        }
        .gesture(
            DragGesture()
                .targetedToEntity(entity)
                .onChanged { value in
                    entity.position = value.convert(value.location3D, from: .local, to: entity.parent!)
                }
        )
    }
}

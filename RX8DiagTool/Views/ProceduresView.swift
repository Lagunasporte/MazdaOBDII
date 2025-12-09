import SwiftUI

// MARK: - Workshop Procedures View

struct ProceduresView: View {
    @State private var selectedCategory: ProcedureCategory? = nil
    @State private var searchText = ""
    @State private var selectedProcedure: WorkshopProcedure?

    var filteredProcedures: [WorkshopProcedure] {
        var procedures = RX8Procedures.allProcedures

        if let category = selectedCategory {
            procedures = procedures.filter { $0.category == category }
        }

        if !searchText.isEmpty {
            procedures = procedures.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText) ||
                $0.symptoms.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }

        return procedures
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        CategoryButton(
                            title: "Todos",
                            isSelected: selectedCategory == nil,
                            color: .gray
                        ) {
                            selectedCategory = nil
                        }

                        ForEach(ProcedureCategory.allCases, id: \.self) { category in
                            CategoryButton(
                                title: category.rawValue,
                                isSelected: selectedCategory == category,
                                color: colorForCategory(category)
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color(.systemGray6))

                // Procedures list
                List {
                    ForEach(filteredProcedures) { procedure in
                        ProcedureRow(procedure: procedure)
                            .onTapGesture {
                                selectedProcedure = procedure
                            }
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Procedimientos")
            .searchable(text: $searchText, prompt: "Buscar procedimientos...")
            .sheet(item: $selectedProcedure) { procedure in
                ProcedureDetailView(procedure: procedure)
            }
        }
    }

    private func colorForCategory(_ category: ProcedureCategory) -> Color {
        switch category {
        case .diagnostic: return .blue
        case .maintenance: return .green
        case .repair: return .orange
        case .emergency: return .red
        case .performance: return .purple
        case .electrical: return .yellow
        }
    }
}

// MARK: - Category Button

struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? color : Color(.systemGray5))
                .cornerRadius(20)
        }
    }
}

// MARK: - Procedure Row

struct ProcedureRow: View {
    let procedure: WorkshopProcedure

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(procedure.title)
                    .font(.headline)
                Spacer()
                DifficultyBadge(difficulty: procedure.difficulty)
            }

            Text(procedure.description.prefix(100) + "...")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)

            HStack {
                Label(procedure.category.rawValue, systemImage: iconForCategory(procedure.category))
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                Label(procedure.estimatedTime, systemImage: "clock")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    private func iconForCategory(_ category: ProcedureCategory) -> String {
        switch category {
        case .diagnostic: return "stethoscope"
        case .maintenance: return "wrench.and.screwdriver"
        case .repair: return "hammer"
        case .emergency: return "exclamationmark.triangle"
        case .performance: return "speedometer"
        case .electrical: return "bolt"
        }
    }
}

// MARK: - Difficulty Badge

struct DifficultyBadge: View {
    let difficulty: ProcedureDifficulty

    var body: some View {
        Text(difficulty.rawValue)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(colorForDifficulty)
            .cornerRadius(8)
    }

    private var colorForDifficulty: Color {
        switch difficulty {
        case .basic: return .green
        case .intermediate: return .yellow
        case .advanced: return .orange
        case .professional: return .red
        }
    }
}

// MARK: - Procedure Detail View

struct ProcedureDetailView: View {
    let procedure: WorkshopProcedure
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0
    @State private var completedSteps: Set<Int> = []

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            DifficultyBadge(difficulty: procedure.difficulty)
                            Spacer()
                            Label(procedure.estimatedTime, systemImage: "clock")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Text(procedure.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Symptoms
                    if !procedure.symptoms.isEmpty {
                        SectionCard(title: "Síntomas", icon: "exclamationmark.bubble") {
                            ForEach(procedure.symptoms, id: \.self) { symptom in
                                HStack(alignment: .top) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                    Text(symptom)
                                        .font(.subheadline)
                                }
                            }
                        }
                    }

                    // Warnings
                    if !procedure.warnings.isEmpty {
                        SectionCard(title: "Advertencias", icon: "exclamationmark.triangle.fill", color: .red) {
                            ForEach(procedure.warnings, id: \.self) { warning in
                                HStack(alignment: .top) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                    Text(warning)
                                        .font(.subheadline)
                                }
                            }
                        }
                    }

                    // Tools
                    if !procedure.tools.isEmpty {
                        SectionCard(title: "Herramientas", icon: "wrench.and.screwdriver") {
                            ForEach(procedure.tools) { tool in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(tool.name)
                                        .font(.subheadline)
                                    if let partNumber = tool.partNumber {
                                        Text("P/N: \(partNumber)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    if let alt = tool.alternative {
                                        Text("Alt: \(alt)")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }

                    // Parts
                    if !procedure.parts.isEmpty {
                        SectionCard(title: "Piezas/Materiales", icon: "shippingbox") {
                            ForEach(procedure.parts, id: \.self) { part in
                                HStack(alignment: .top) {
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 6))
                                        .foregroundColor(.secondary)
                                        .padding(.top, 6)
                                    Text(part)
                                        .font(.subheadline)
                                }
                            }
                        }
                    }

                    // Steps
                    SectionCard(title: "Pasos", icon: "list.number") {
                        ForEach(procedure.steps) { step in
                            StepView(
                                step: step,
                                isCompleted: completedSteps.contains(step.number),
                                isCurrent: currentStep == step.number
                            ) {
                                if completedSteps.contains(step.number) {
                                    completedSteps.remove(step.number)
                                } else {
                                    completedSteps.insert(step.number)
                                    if step.number == currentStep {
                                        currentStep += 1
                                    }
                                }
                            }
                        }
                    }

                    // Tips
                    if !procedure.tips.isEmpty {
                        SectionCard(title: "Consejos", icon: "lightbulb", color: .yellow) {
                            ForEach(procedure.tips, id: \.self) { tip in
                                HStack(alignment: .top) {
                                    Image(systemName: "lightbulb.fill")
                                        .foregroundColor(.yellow)
                                        .font(.caption)
                                    Text(tip)
                                        .font(.subheadline)
                                }
                            }
                        }
                    }

                    // Related DTCs
                    if !procedure.relatedDTCs.isEmpty {
                        SectionCard(title: "DTCs Relacionados", icon: "exclamationmark.octagon") {
                            FlowLayout(spacing: 8) {
                                ForEach(procedure.relatedDTCs, id: \.self) { dtc in
                                    Text(dtc)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.red.opacity(0.2))
                                        .foregroundColor(.red)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(procedure.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Section Card

struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    var color: Color = .blue
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
            }

            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Step View

struct StepView: View {
    let step: ProcedureStep
    let isCompleted: Bool
    let isCurrent: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Button(action: onToggle) {
                    ZStack {
                        Circle()
                            .stroke(isCompleted ? Color.green : (isCurrent ? Color.blue : Color.gray), lineWidth: 2)
                            .frame(width: 28, height: 28)

                        if isCompleted {
                            Image(systemName: "checkmark")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        } else {
                            Text("\(step.number)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(isCurrent ? .blue : .gray)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(step.instruction)
                        .font(.subheadline)
                        .strikethrough(isCompleted)
                        .foregroundColor(isCompleted ? .secondary : .primary)

                    if let warning = step.warning {
                        HStack(alignment: .top, spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                                .font(.caption2)
                            Text(warning)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }

                    if let tip = step.tip {
                        HStack(alignment: .top, spacing: 4) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                                .font(.caption2)
                            Text(tip)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                        .background(Color.yellow.opacity(0.1))
                        .cornerRadius(8)
                    }

                    if let expectedValue = step.expectedValue {
                        HStack(spacing: 4) {
                            Image(systemName: "target")
                                .foregroundColor(.blue)
                                .font(.caption2)
                            Text("Esperado: \(expectedValue)")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }

            Divider()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
                self.size.width = max(self.size.width, currentX)
            }

            self.size.height = currentY + lineHeight
        }
    }
}

#Preview {
    ProceduresView()
}

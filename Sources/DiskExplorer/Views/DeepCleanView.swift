import SwiftUI

public struct DeepCleanView: View {
    @StateObject private var viewModel = DeepCleanViewModel()
    var onCleanCompleted: (() -> Void)?
    
    public init(onCleanCompleted: (() -> Void)? = nil) {
        self.onCleanCompleted = onCleanCompleted
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Deep Clean")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Safely remove system junk to free up space.")
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 20)
            
            if viewModel.isScanning {
                VStack(spacing: 20) {
                    ProgressView()
                    Text("Scanning for junk...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.isCleaning {
                VStack(spacing: 20) {
                    ProgressView()
                    Text("Cleaning...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.categories) { category in
                        HStack(spacing: 16) {
                            Toggle("", isOn: Binding(
                                get: { category.isSelected },
                                set: { _ in viewModel.toggleSelection(id: category.id) }
                            ))
                            .labelsHidden()
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(category.name)
                                    .font(.headline)
                                Text(category.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if let displayValue = category.displayValue {
                                Text(displayValue)
                                    .font(.callout)
                                    .fontWeight(.semibold)
                            } else {
                                Text(ByteFormatter.format(category.size))
                                    .font(.callout)
                                    .fontWeight(.semibold)
                                    .monospacedDigit()
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                .listStyle(.inset)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
                
                Spacer()
                
                // Footer
                HStack {
                    VStack(alignment: .leading) {
                        Text("Selected for cleanup:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(ByteFormatter.format(viewModel.totalSelectedSize))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        Task {
                            await viewModel.clean()
                            onCleanCompleted?()
                        }
                    }) {
                        Text("Clean")
                            .font(.headline)
                            .frame(minWidth: 120)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 24)
                            .background(
                                LinearGradient(colors: viewModel.hasSelectedItems ? [.cyan, .blue] : [.gray, .gray.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.hasSelectedItems)
                }
                .padding()
                .background(Color(NSColor.windowBackgroundColor))
                .cornerRadius(12)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(NSColor.windowBackgroundColor))
        .alert(isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Alert(
                title: Text("Cleanup Incomplete"),
                message: Text(viewModel.errorMessage ?? "An unknown error occurred."),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            Task {
                await viewModel.scan()
            }
        }
    }
}

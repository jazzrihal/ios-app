import SwiftUI

/// Configurable photo grid with built-in infinite scroll sentinel.
///
/// Wraps a `LazyVGrid` with a customisable column count and a load-more
/// trigger at the bottom. The caller provides cell content via a
/// `@ViewBuilder` that receives the item index and value.
struct PhotoGrid<Item: Identifiable, Cell: View>: View {
    let items: [Item]
    let columns: Int
    var hasMorePages: Bool = false
    var isLoadingMore: Bool = false
    var onLoadMore: (() -> Void)?
    @ViewBuilder let cell: (Int, Item) -> Cell

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: AppStyle.Spacing.grid), count: columns)
    }

    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: AppStyle.Spacing.grid) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                cell(index, item)
            }

            if hasMorePages, let onLoadMore {
                Color.clear
                    .frame(height: 44)
                    .overlay {
                        if isLoadingMore {
                            ProgressView()
                        }
                    }
                    .gridCellColumns(columns)
                    .onAppear(perform: onLoadMore)
            }
        }
    }
}

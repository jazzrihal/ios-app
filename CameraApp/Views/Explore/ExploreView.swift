import MapKit
import SwiftUI

struct ExploreView: View {
    // MARK: - State

    @Environment(MomentsStore.self) private var store

    @State private var selectedDate = Date()
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )
    @State private var pinnedCoordinate: CLLocationCoordinate2D?
    @State private var locationName: String?
    @State private var isReverseGeocoding = false
    @State private var posts: [ImagePost] = []
    @State private var hasSearched = false
    @State private var isSearching = false
    @State private var showDatePicker = false
    @State private var showMap = false
    @State private var momentSaved = false
    @State private var searchCompleter = LocationSearchCompleter()
    @State private var isResolvingPlace = false
    @FocusState private var isSearchFieldFocused: Bool

    // Navigation state (outside lazy container)
    @State private var navigateToProfileUser: User? = nil
    @State private var navigateToPostIndex: Int? = nil

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // ── Date/Time selector ──
                    dateSelector

                    // ── Location selector ──
                    locationSelector

                    // ── Search button ──
                    searchButton

                    // ── Save Moment button ──
                    saveMomentButton

                    // ── Results ──
                    resultsSection
                }
            }
            .navigationTitle("Explore")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: Binding(
                get: { navigateToProfileUser != nil },
                set: { if !$0 { navigateToProfileUser = nil } }
            )) {
                if let user = navigateToProfileUser {
                    FriendProfileView(user: user)
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { navigateToPostIndex != nil },
                set: { if !$0 { navigateToPostIndex = nil } }
            )) {
                if let index = navigateToPostIndex {
                    PostDetailView(posts: posts, initialIndex: index, queryDate: selectedDate)
                }
            }
            .onAppear {
                loadPendingMoment()
            }
            .onChange(of: store.pendingMoment?.id) { _, _ in
                loadPendingMoment()
            }
        }
    }

    // MARK: - Subviews

    private var dateSelector: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    showDatePicker.toggle()
                    showMap = false
                }
            } label: {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .font(.title3)
                        .foregroundStyle(.blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Search around")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(selectedDate.formatted(.dateTime.month(.wide).day().year().hour().minute()))
                            .font(.subheadline.weight(.medium))
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(showDatePicker ? 180 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)

            if showDatePicker {
                DatePicker(
                    "Select date & time",
                    selection: $selectedDate,
                    in: ...Date(),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var locationSelector: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    showMap.toggle()
                    showDatePicker = false
                }
            } label: {
                HStack {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.title3)
                        .foregroundStyle(.red)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Location")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if isReverseGeocoding {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.mini)
                                Text("Finding location…")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                        } else if let locationName {
                            Text(locationName)
                                .font(.subheadline.weight(.medium))
                        } else {
                            Text("Tap to choose on map")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(showMap ? 180 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)

            if showMap {
                VStack(alignment: .leading, spacing: 8) {
                    // ── Place search bar ──
                    placeSearchBar

                    // ── Search results overlay ──
                    if !searchCompleter.results.isEmpty && !searchCompleter.queryFragment.isEmpty {
                        placeSearchResults
                    }

                    HStack {
                        Image(systemName: "hand.tap")
                            .foregroundStyle(.secondary)
                        Text(pinnedCoordinate != nil ? "Tap the map to move pin" : "Tap the map to drop a pin")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 4)

                    MapReader { proxy in
                        Map(position: $cameraPosition) {
                            if let pin = pinnedCoordinate {
                                Annotation("Search here", coordinate: pin) {
                                    ZStack {
                                        Circle()
                                            .fill(.blue.opacity(0.15))
                                            .frame(width: 44, height: 44)
                                        Circle()
                                            .fill(.blue.opacity(0.3))
                                            .frame(width: 28, height: 28)
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.title2)
                                            .foregroundStyle(.white, .blue)
                                    }
                                }
                            }
                        }
                        .mapStyle(.standard(elevation: .realistic))
                        .mapControls {
                            MapUserLocationButton()
                            MapCompass()
                            MapScaleView()
                        }
                        .onTapGesture { screenPoint in
                            if let coord = proxy.convert(screenPoint, from: .local) {
                                withAnimation(.spring(duration: 0.3)) {
                                    pinnedCoordinate = coord
                                }
                                reverseGeocode(coord)
                                dismissPlaceSearch()
                            }
                        }
                    }
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var placeSearchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.subheadline)

            TextField("Search for a place…", text: Binding(
                get: { searchCompleter.queryFragment },
                set: { searchCompleter.queryFragment = $0 }
            ))
            .font(.subheadline)
            .focused($isSearchFieldFocused)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.words)
            .submitLabel(.search)

            if isResolvingPlace {
                ProgressView()
                    .controlSize(.mini)
            } else if !searchCompleter.queryFragment.isEmpty {
                Button {
                    dismissPlaceSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private var placeSearchResults: some View {
        VStack(spacing: 0) {
            ForEach(searchCompleter.results.prefix(5), id: \.self) { completion in
                Button {
                    selectPlace(completion)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.red)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(completion.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            if !completion.subtitle.isEmpty {
                                Text(completion.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        Image(systemName: "arrow.turn.down.left")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)

                if completion != searchCompleter.results.prefix(5).last {
                    Divider()
                        .padding(.leading, 44)
                }
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private var searchButton: some View {
        Button {
            performSearch()
        } label: {
            HStack(spacing: 8) {
                if isSearching {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "magnifyingglass")
                }
                Text(isSearching ? "Searching…" : "Find Nearby Posts")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .accessibilityIdentifier("FindNearbyPostsButton")
        .buttonStyle(.borderedProminent)
        .tint(.blue)
        .disabled(pinnedCoordinate == nil || isSearching)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var saveMomentButton: some View {
        if hasSearched && !posts.isEmpty {
            Button {
                saveMoment()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: momentSaved ? "checkmark.circle.fill" : "bookmark.fill")
                    Text(momentSaved ? "Moment Saved!" : "Save this Moment")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .accessibilityIdentifier("SaveMomentButton")
            .buttonStyle(.bordered)
            .tint(momentSaved ? .green : .purple)
            .disabled(momentSaved)
            .padding(.horizontal, 16)
        }
    }

    private var resultsSection: some View {
        Group {
            if hasSearched {
                if posts.isEmpty {
                    ContentUnavailableView(
                        "No Posts Found",
                        systemImage: "photo.on.rectangle.angled",
                        description: Text("Try a different location or time range.")
                    )
                    .padding(.top, 28)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                            PostCard(
                                post: post,
                                queryDate: selectedDate,
                                onTapProfile: {
                                    navigateToProfileUser = post.user
                                },
                                onTapPost: {
                                    navigateToPostIndex = index
                                }
                            )
                            if index < posts.count - 1 {
                                Divider()
                                    .foregroundStyle(.quaternary)
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                    .padding(.bottom, 24)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "sparkle.magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text("Pick a date & drop a pin to explore")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 28)
            }
        }
    }

    // MARK: - Actions

    private func selectPlace(_ completion: MKLocalSearchCompletion) {
        isSearchFieldFocused = false
        isResolvingPlace = true

        Task {
            if let mapItem = await searchCompleter.resolve(completion) {
                let coord = mapItem.placemark.coordinate

                withAnimation(.spring(duration: 0.3)) {
                    pinnedCoordinate = coord
                    cameraPosition = .region(
                        MKCoordinateRegion(
                            center: coord,
                            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                        )
                    )
                }

                // Build a nice location name from the map item
                let placemark = mapItem.placemark
                let city = placemark.locality
                let country = placemark.country
                let name = mapItem.name

                if let name, let city, let country {
                    locationName = "\(name), \(city), \(country)"
                } else if let city, let country {
                    locationName = "\(city), \(country)"
                } else if let name {
                    locationName = name
                } else {
                    reverseGeocode(coord)
                }
            }

            isResolvingPlace = false
            searchCompleter.queryFragment = ""
        }
    }

    private func dismissPlaceSearch() {
        searchCompleter.queryFragment = ""
        isSearchFieldFocused = false
    }

    private func reverseGeocode(_ coordinate: CLLocationCoordinate2D) {
        isReverseGeocoding = true
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let coordinateFallback = String(
            format: "%.4f, %.4f",
            coordinate.latitude,
            coordinate.longitude
        )

        geocoder.reverseGeocodeLocation(location) { placemarks, _ in
            isReverseGeocoding = false

            guard let placemark = placemarks?.first else {
                locationName = coordinateFallback
                return
            }

            let city = placemark.locality
            let country = placemark.country
            switch (city, country) {
            case let (c?, co?):
                locationName = "\(c), \(co)"
            case let (nil, co?):
                locationName = co
            case let (c?, nil):
                locationName = c
            default:
                locationName = coordinateFallback
            }
        }
    }

    private func saveMoment() {
        guard let coord = pinnedCoordinate, let name = locationName else { return }
        store.addMoment(date: selectedDate, locationName: name, coordinate: coord)

        withAnimation {
            momentSaved = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                momentSaved = false
            }
        }
    }

    private func loadPendingMoment() {
        guard let moment = store.pendingMoment else { return }
        selectedDate = moment.date
        pinnedCoordinate = moment.coordinate
        locationName = moment.locationName
        showDatePicker = false
        showMap = false
        momentSaved = false

        // Center the map on the moment's location
        cameraPosition = .region(
            MKCoordinateRegion(
                center: moment.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        )

        store.pendingMoment = nil
        performSearch()
    }

    private func performSearch() {
        guard let coord = pinnedCoordinate else { return }
        isSearching = true
        hasSearched = false
        momentSaved = false

        // Collapse all expanded UI elements
        withAnimation(.spring(duration: 0.3)) {
            showDatePicker = false
            showMap = false
        }
        dismissPlaceSearch()

        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.spring(duration: 0.4)) {
                posts = ImagePost.samplePosts(near: coord, around: selectedDate)
                hasSearched = true
                isSearching = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ExploreView()
        .environment(MomentsStore())
        .environment(FriendsStore())
}

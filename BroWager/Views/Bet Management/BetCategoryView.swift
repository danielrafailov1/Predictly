//
//  BetCategoryView.swift
//  BroWager
//
//  Created by Daniel Rafailov on 2025-07-30.
//
import SwiftUI

struct BetCategoryView: View {
    @Binding var navPath: NavigationPath
    let email: String
    let userId: UUID?
    let betType: String
    
    @State private var selectedCategory: BetCategory? = nil
    @State private var isNavigating = false
    
    enum BetCategory: String, CaseIterable {
        case sports = "Sports"
        case food = "Food"
        case lifeEvents = "Life Events"
        case politics = "Politics"
        case entertainment = "Entertainment"
        case other = "Other"
        
        var icon: String {
            switch self {
            case .sports:
                return "sportscourt"
            case .food:
                return "fork.knife"
            case .lifeEvents:
                return "heart.fill"
            case .politics:
                return "building.columns"
            case .entertainment:
                return "tv.fill"
            case .other:
                return "questionmark.circle"
            }
        }
        
        var color: Color {
            switch self {
            case .sports:
                return .orange
            case .food:
                return .green
            case .lifeEvents:
                return .pink
            case .politics:
                return .blue
            case .entertainment:
                return .yellow
            case .other:
                return .purple
            }
        }
        
        var description: String {
            switch self {
            case .sports:
                return "Games, matches, tournaments"
            case .food:
                return "Cooking, eating, restaurants"
            case .lifeEvents:
                return "Personal milestones & events"
            case .politics:
                return "Elections, policies, debates"
            case .entertainment:
                return "Movies, TV shows, concerts, events"
            case .other:
                return "Everything else"
            }
        }
        
        // AI prompt context for this category
        var aiPromptContext: String {
            switch self {
            case .sports:
                return "sports-related activities like games, matches, tournaments, team performance, player statistics, athletic competitions"
            case .food:
                return "food-related activities like cooking challenges, restaurant choices, eating contests, recipe outcomes, taste tests"
            case .lifeEvents:
                return "personal life events like birthdays, relationships, career milestones, personal achievements, family events"
            case .politics:
                return "political events like elections, policy decisions, political debates, government actions, political predictions"
            case .entertainment:
                return "entertainment-related activities like movie reviews, TV show recommendations, concert tickets, event outcomes, entertainment predictions"
            case .other:
                return "general everyday activities, random events, social situations, entertainment, technology, weather, or any other topics"
            }
        }
    }
    
    var body: some View {
        ZStack {
            // App background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.1, green: 0.1, blue: 0.2), Color(red: 0.15, green: 0.15, blue: 0.25)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Choose challenge category")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("Select the type of challenge you want to create")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                .padding(.horizontal)
                
                // Category Cards
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    ForEach(BetCategory.allCases, id: \.self) { category in
                        CategoryCard(
                            category: category,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = category
                            // Add haptic feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            
                            // Navigate after a brief delay for visual feedback
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isNavigating = true
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer(minLength: 20)
            }
            .padding(.bottom, 30)
            
        }
        .navigationDestination(isPresented: $isNavigating) {
            if let category = selectedCategory {
                NormalBetView(navPath: $navPath, email: email, userId: userId, selectedCategory: selectedCategory, betType: betType)
            }
        }
    }
}

struct CategoryCard: View {
    let category: BetCategoryView.BetCategory
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 16) {
                // Icon container
                ZStack {
                    Circle()
                        .fill(category.color.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: category.icon)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(category.color)
                }
                
                // Category info
                VStack(spacing: 4) {
                    Text(category.rawValue)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text(category.description)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(isSelected ? 0.2 : 0.1),
                                Color.white.opacity(isSelected ? 0.15 : 0.05)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? category.color : Color.white.opacity(0.2),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .shadow(
                color: isSelected ? category.color.opacity(0.3) : Color.black.opacity(0.1),
                radius: isSelected ? 8 : 4,
                x: 0,
                y: isSelected ? 4 : 2
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isSelected)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
    }
}

#Preview {
    NavigationView {
        BetCategoryView(
            navPath: .constant(NavigationPath()),
            email: "preview@example.com",
            userId: UUID(),
            betType: "normal"
        )
    }
}

//
//  CreditsView.swift
//  BroWager
//
//  Created by Daniel Rafailov on 2025-07-31.
//
import SwiftUI

struct CreditsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient matching your app's theme
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.1, green: 0.1, blue: 0.2),
                        Color(red: 0.15, green: 0.15, blue: 0.25)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 12) {
                            Text("Credits")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("Meet the team behind the app")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                        
                        // Developers Section
                        CreditsSectionView(
                            title: "Developers",
                            iconName: "laptopcomputer",
                            iconColor: .blue,
                            credits: [
                                CreditItem(
                                    name: "Daniel Rafailov",
                                    role: "Cofounder and Lead Developer",
                                    description: "3rd year Computer Science Specialist at University of Toronto"
                                ),
                                CreditItem(
                                    name: "Nachuan Wang",
                                    role: "Cofounder and Lead Developer",
                                    description: "3rd year Math and CS Double Major at University of Toronto"
                                )
                            ]
                        )
                        
                        CreditsSectionView(
                            title: "Contributers",
                            iconName: "person.3",
                            iconColor: .yellow,
                            credits: [
                                CreditItem(
                                    name: "Ali Rahbar",
                                    role: "AI Optimizer",
                                    description: "3rd year Computer Science Specialist with a minor in Economics at University of Toronto"
                                )
                            ]
                        )
                        
                        // Design Team Section
                        CreditsSectionView(
                            title: "Structural Engineer",
                            iconName: "paintbrush.pointed",
                            iconColor: .purple,
                            credits: [
                                CreditItem(
                                    name: "DnovTheRuler",
                                    role: "NVM Diagram Analyzer",
                                    description: "Has not been paid yet"
                                )
                            ]
                        )
                        
                        // Beta Testers Section
                        CreditsSectionView(
                            title: "Beta Testers",
                            iconName: "testtube.2",
                            iconColor: .green,
                            credits: [
                                CreditItem(name: "Christian Nicholas Fisla", role: "Beta Tester", description: nil),
                                CreditItem(name: "Julian George Fisla", role: "Beta Tester", description: nil),
                                CreditItem(name: "Ben Adam Rafailov", role: "Beta Tester", description: nil),
                                CreditItem(name: "Jonathan Sin-Sara", role: "Beta Tester", description: nil),
                                CreditItem(name: "Alexei Sokolovski", role: "Beta Tester", description: nil)
                            ]
                        )
                        
                        // Thank You Section
                        VStack(spacing: 12) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.red)
                            
                            Text("Thank You!")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Special thanks to everyone who contributed to making this app possible.")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        .padding(.vertical, 20)
                        .padding(.horizontal, 24)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                        .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .semibold))
                }
            }
        }
        .onAppear {
            // Set navigation bar appearance
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = .clear
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

struct CreditsSectionView: View {
    let title: String
    let iconName: String
    let iconColor: Color
    let credits: [CreditItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(iconColor)
                
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.horizontal, 24)
            
            // Credits List
            VStack(spacing: 12) {
                ForEach(credits) { credit in
                    CreditItemView(credit: credit)
                }
            }
        }
    }
}

struct CreditItemView: View {
    let credit: CreditItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(credit.name)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            
            Text(credit.role)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.orange)
            
            if let description = credit.description {
                Text(description)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal, 24)
    }
}

struct CreditItem: Identifiable {
    let id = UUID()
    let name: String
    let role: String
    let description: String?
}

#Preview {
    CreditsView()
}

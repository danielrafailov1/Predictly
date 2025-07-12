import Foundation
 
enum BetFlowPath: Hashable {
    case partyLobby(game: BaseballGame, gameName: String, email: String)
    case createParty(partyCode: String, betType: BetType, userEmail: String)
    case gameEvent(game: BaseballGame, partyId: Int64, userId: String, betType: BetType, partyCode: String, userEmail: String)
    case partyDetails(partyCode: String, email: String)
} 

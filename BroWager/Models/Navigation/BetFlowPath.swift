import Foundation
 
enum BetFlowPath: Hashable {
    case partyLobby(game: BaseballGame, gameName: String, email: String)
    case createParty(party_code: String, betType: BetType, userEmail: String)
    case gameEvent(game: BaseballGame, partyId: Int64, userId: String, betType: BetType, party_code: String, userEmail: String)
    case partyDetails(party_code: String, email: String)
}

-- BroWager Database Security Policies (FIXED VERSION)
-- This script enables RLS on all tables and creates appropriate security policies
-- Fixed type casting issues between UUID and text columns

-- Enable RLS on all tables
ALTER TABLE "Login Information" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Username" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Profile Images" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "user_wins" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "user_device_tokens" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Friends" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Parties" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Party Members" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Party Invites" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "DirectMessages" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "PartyChatMessages" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "User Bets" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "partybets" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Game" ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- LOGIN INFORMATION TABLE POLICIES (user_id is UUID)
-- ============================================================================

-- Users can only read their own login information
CREATE POLICY "Users can view own login info" ON "Login Information"
    FOR SELECT USING (auth.uid() = user_id::uuid);

-- Users can only update their own login information
CREATE POLICY "Users can update own login info" ON "Login Information"
    FOR UPDATE USING (auth.uid() = user_id::uuid);

-- Users can only insert their own login information
CREATE POLICY "Users can insert own login info" ON "Login Information"
    FOR INSERT WITH CHECK (auth.uid() = user_id::uuid);

-- Users can only delete their own login information
CREATE POLICY "Users can delete own login info" ON "Login Information"
    FOR DELETE USING (auth.uid() = user_id::uuid);

-- ============================================================================
-- USERNAME TABLE POLICIES (user_id is UUID)
-- ============================================================================

-- Users can only read their own username
CREATE POLICY "Users can view own username" ON "Username"
    FOR SELECT USING (auth.uid() = user_id::uuid);

-- Users can only update their own username
CREATE POLICY "Users can update own username" ON "Username"
    FOR UPDATE USING (auth.uid() = user_id::uuid);

-- Users can only insert their own username
CREATE POLICY "Users can insert own username" ON "Username"
    FOR INSERT WITH CHECK (auth.uid() = user_id::uuid);

-- Users can only delete their own username
CREATE POLICY "Users can delete own username" ON "Username"
    FOR DELETE USING (auth.uid() = user_id::uuid);

-- ============================================================================
-- PROFILE IMAGES TABLE POLICIES (user_id is UUID)
-- ============================================================================

-- Users can only read their own profile images
CREATE POLICY "Users can view own profile images" ON "Profile Images"
    FOR SELECT USING (auth.uid() = user_id::uuid);

-- Users can only update their own profile images
CREATE POLICY "Users can update own profile images" ON "Profile Images"
    FOR UPDATE USING (auth.uid() = user_id::uuid);

-- Users can only insert their own profile images
CREATE POLICY "Users can insert own profile images" ON "Profile Images"
    FOR INSERT WITH CHECK (auth.uid() = user_id::uuid);

-- Users can only delete their own profile images
CREATE POLICY "Users can delete own profile images" ON "Profile Images"
    FOR DELETE USING (auth.uid() = user_id::uuid);

-- ============================================================================
-- USER WINS TABLE POLICIES (user_id is UUID)
-- ============================================================================

-- Users can only read their own wins
CREATE POLICY "Users can view own wins" ON "user_wins"
    FOR SELECT USING (auth.uid() = user_id::uuid);

-- Users can only update their own wins
CREATE POLICY "Users can update own wins" ON "user_wins"
    FOR UPDATE USING (auth.uid() = user_id::uuid);

-- Users can only insert their own wins
CREATE POLICY "Users can insert own wins" ON "user_wins"
    FOR INSERT WITH CHECK (auth.uid() = user_id::uuid);

-- Users can only delete their own wins
CREATE POLICY "Users can delete own wins" ON "user_wins"
    FOR DELETE USING (auth.uid() = user_id::uuid);

-- ============================================================================
-- USER DEVICE TOKENS TABLE POLICIES (user_id is TEXT)
-- ============================================================================

-- Users can only read their own device tokens
CREATE POLICY "Users can view own device tokens" ON "user_device_tokens"
    FOR SELECT USING (auth.uid()::text = user_id);

-- Users can only update their own device tokens
CREATE POLICY "Users can update own device tokens" ON "user_device_tokens"
    FOR UPDATE USING (auth.uid()::text = user_id);

-- Users can only insert their own device tokens
CREATE POLICY "Users can insert own device tokens" ON "user_device_tokens"
    FOR INSERT WITH CHECK (auth.uid()::text = user_id);

-- Users can only delete their own device tokens
CREATE POLICY "Users can delete own device tokens" ON "user_device_tokens"
    FOR DELETE USING (auth.uid()::text = user_id);

-- ============================================================================
-- FRIENDS TABLE POLICIES (user_id and friend_id are UUID)
-- ============================================================================

-- Users can read friend relationships where they are involved
CREATE POLICY "Users can view friend relationships" ON "Friends"
    FOR SELECT USING (auth.uid() = user_id::uuid OR auth.uid() = friend_id::uuid);

-- Users can insert friend relationships where they are the initiator
CREATE POLICY "Users can insert friend relationships" ON "Friends"
    FOR INSERT WITH CHECK (auth.uid() = user_id::uuid);

-- Users can update friend relationships where they are involved
CREATE POLICY "Users can update friend relationships" ON "Friends"
    FOR UPDATE USING (auth.uid() = user_id::uuid OR auth.uid() = friend_id::uuid);

-- Users can delete friend relationships where they are involved
CREATE POLICY "Users can delete friend relationships" ON "Friends"
    FOR DELETE USING (auth.uid() = user_id::uuid OR auth.uid() = friend_id::uuid);

-- ============================================================================
-- PARTIES TABLE POLICIES (created_by is UUID)
-- ============================================================================

-- Users can read all parties (for discovery and joining)
CREATE POLICY "Users can view all parties" ON "Parties"
    FOR SELECT USING (true);

-- Users can insert parties (create new parties)
CREATE POLICY "Users can create parties" ON "Parties"
    FOR INSERT WITH CHECK (auth.uid() = created_by::uuid);

-- Users can update parties they created
CREATE POLICY "Users can update own parties" ON "Parties"
    FOR UPDATE USING (auth.uid() = created_by::uuid);

-- Users can delete parties they created
CREATE POLICY "Users can delete own parties" ON "Parties"
    FOR DELETE USING (auth.uid() = created_by::uuid);

-- ============================================================================
-- PARTY MEMBERS TABLE POLICIES (user_id is UUID, party_id is BIGINT)
-- ============================================================================

-- Users can read party members for parties they're in
CREATE POLICY "Users can view party members" ON "Party Members"
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM "Party Members" pm 
            WHERE pm.party_id = "Party Members".party_id 
            AND pm.user_id::uuid = auth.uid()
        )
    );

-- Users can insert themselves as party members
CREATE POLICY "Users can join parties" ON "Party Members"
    FOR INSERT WITH CHECK (auth.uid() = user_id::uuid);

-- Users can update their own party membership
CREATE POLICY "Users can update own party membership" ON "Party Members"
    FOR UPDATE USING (auth.uid() = user_id::uuid);

-- Users can leave parties (delete their own membership)
CREATE POLICY "Users can leave parties" ON "Party Members"
    FOR DELETE USING (auth.uid() = user_id::uuid);

-- Party creators can remove any member
CREATE POLICY "Party creators can remove members" ON "Party Members"
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM "Parties" p 
            WHERE p.id = "Party Members".party_id 
            AND p.created_by::uuid = auth.uid()
        )
    );

-- ============================================================================
-- PARTY INVITES TABLE POLICIES (inviter_user_id and invitee_user_id are UUID)
-- ============================================================================

-- Users can read invites they sent or received
CREATE POLICY "Users can view party invites" ON "Party Invites"
    FOR SELECT USING (auth.uid() = inviter_user_id::uuid OR auth.uid() = invitee_user_id::uuid);

-- Users can send invites
CREATE POLICY "Users can send party invites" ON "Party Invites"
    FOR INSERT WITH CHECK (auth.uid() = inviter_user_id::uuid);

-- Users can update invites they sent or received
CREATE POLICY "Users can update party invites" ON "Party Invites"
    FOR UPDATE USING (auth.uid() = inviter_user_id::uuid OR auth.uid() = invitee_user_id::uuid);

-- Users can delete invites they sent or received
CREATE POLICY "Users can delete party invites" ON "Party Invites"
    FOR DELETE USING (auth.uid() = inviter_user_id::uuid OR auth.uid() = invitee_user_id::uuid);

-- ============================================================================
-- DIRECT MESSAGES TABLE POLICIES (sender_id and receiver_id are UUID)
-- ============================================================================

-- Users can read messages they sent or received
CREATE POLICY "Users can view direct messages" ON "DirectMessages"
    FOR SELECT USING (auth.uid() = sender_id::uuid OR auth.uid() = receiver_id::uuid);

-- Users can send messages
CREATE POLICY "Users can send direct messages" ON "DirectMessages"
    FOR INSERT WITH CHECK (auth.uid() = sender_id::uuid);

-- Users can update messages they sent
CREATE POLICY "Users can update own messages" ON "DirectMessages"
    FOR UPDATE USING (auth.uid() = sender_id::uuid);

-- Users can delete messages they sent
CREATE POLICY "Users can delete own messages" ON "DirectMessages"
    FOR DELETE USING (auth.uid() = sender_id::uuid);

-- ============================================================================
-- PARTY CHAT MESSAGES TABLE POLICIES (user_id is UUID, party_id is BIGINT)
-- ============================================================================

-- Users can read chat messages for parties they're in
CREATE POLICY "Users can view party chat messages" ON "PartyChatMessages"
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM "Party Members" pm 
            WHERE pm.party_id = "PartyChatMessages".party_id 
            AND pm.user_id::uuid = auth.uid()
        )
    );

-- Users can send chat messages to parties they're in
CREATE POLICY "Users can send party chat messages" ON "PartyChatMessages"
    FOR INSERT WITH CHECK (
        auth.uid() = user_id::uuid AND
        EXISTS (
            SELECT 1 FROM "Party Members" pm 
            WHERE pm.party_id = "PartyChatMessages".party_id 
            AND pm.user_id::uuid = auth.uid()
        )
    );

-- Users can update their own chat messages
CREATE POLICY "Users can update own chat messages" ON "PartyChatMessages"
    FOR UPDATE USING (auth.uid() = user_id::uuid);

-- Users can delete their own chat messages
CREATE POLICY "Users can delete own chat messages" ON "PartyChatMessages"
    FOR DELETE USING (auth.uid() = user_id::uuid);

-- ============================================================================
-- USER BETS TABLE POLICIES (user_id is TEXT, party_id is BIGINT)
-- ============================================================================

-- Users can read their own bets
CREATE POLICY "Users can view own bets" ON "User Bets"
    FOR SELECT USING (auth.uid()::text = user_id);

-- Users can read bets for parties they're in (for leaderboards, etc.)
CREATE POLICY "Users can view party bets" ON "User Bets"
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM "Party Members" pm 
            WHERE pm.party_id = "User Bets".party_id 
            AND pm.user_id::uuid = auth.uid()
        )
    );

-- Users can insert their own bets
CREATE POLICY "Users can place bets" ON "User Bets"
    FOR INSERT WITH CHECK (auth.uid()::text = user_id);

-- Users can update their own bets
CREATE POLICY "Users can update own bets" ON "User Bets"
    FOR UPDATE USING (auth.uid()::text = user_id);

-- Users can delete their own bets
CREATE POLICY "Users can delete own bets" ON "User Bets"
    FOR DELETE USING (auth.uid()::text = user_id);

-- ============================================================================
-- PARTYBETS TABLE POLICIES (user_id is UUID, party_id is BIGINT)
-- ============================================================================

-- Users can read their own party bets
CREATE POLICY "Users can view own party bets" ON "partybets"
    FOR SELECT USING (auth.uid() = user_id::uuid);

-- Users can read party bets for parties they're in
CREATE POLICY "Users can view party bets in joined parties" ON "partybets"
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM "Party Members" pm 
            WHERE pm.party_id = "partybets".party_id 
            AND pm.user_id::uuid = auth.uid()
        )
    );

-- Users can insert their own party bets
CREATE POLICY "Users can place party bets" ON "partybets"
    FOR INSERT WITH CHECK (auth.uid() = user_id::uuid);

-- Users can update their own party bets
CREATE POLICY "Users can update own party bets" ON "partybets"
    FOR UPDATE USING (auth.uid() = user_id::uuid);

-- Users can delete their own party bets
CREATE POLICY "Users can delete own party bets" ON "partybets"
    FOR DELETE USING (auth.uid() = user_id::uuid);

-- ============================================================================
-- GAME TABLE POLICIES
-- ============================================================================

-- All authenticated users can read game information
CREATE POLICY "Users can view games" ON "Game"
    FOR SELECT USING (auth.role() = 'authenticated');

-- Only authenticated users can insert games (if needed)
CREATE POLICY "Users can create games" ON "Game"
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Only authenticated users can update games (if needed)
CREATE POLICY "Users can update games" ON "Game"
    FOR UPDATE USING (auth.role() = 'authenticated');

-- Only authenticated users can delete games (if needed)
CREATE POLICY "Users can delete games" ON "Game"
    FOR DELETE USING (auth.role() = 'authenticated');

-- ============================================================================
-- ADDITIONAL SECURITY MEASURES
-- ============================================================================

-- Create a function to check if user is authenticated
CREATE OR REPLACE FUNCTION is_authenticated()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN auth.role() = 'authenticated';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a function to get current user ID
CREATE OR REPLACE FUNCTION get_current_user_id()
RETURNS TEXT AS $$
BEGIN
    RETURN auth.uid()::text;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant necessary permissions to authenticated users
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Grant necessary permissions to anon users (for public data only)
GRANT USAGE ON SCHEMA public TO anon;
GRANT SELECT ON "Game" TO anon; -- Allow anonymous users to view games

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Check which tables have RLS enabled
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
ORDER BY tablename;

-- Check existing policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies 
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- OpenBeta Seed Data v2
-- Test data for schema-v2.sql

-- ============================================================================
-- USERS
-- ============================================================================
INSERT INTO users (id, username, email, display_name, bio, is_editor, is_admin) VALUES
    ('a0000000-0000-0000-0000-000000000001', 'alex_honnold', 'alex@example.com', 'Alex Honnold', 'Free soloist. No big deal.', TRUE, FALSE),
    ('a0000000-0000-0000-0000-000000000002', 'lynn_hill', 'lynn@example.com', 'Lynn Hill', 'First free ascent of The Nose.', TRUE, FALSE),
    ('a0000000-0000-0000-0000-000000000003', 'adam_ondra', 'adam@example.com', 'Adam Ondra', 'Czech crusher.', TRUE, FALSE),
    ('a0000000-0000-0000-0000-000000000004', 'weekend_warrior', 'weekendwarrior@example.com', 'Weekend Warrior', 'V3 is my project grade.', FALSE, FALSE),
    ('a0000000-0000-0000-0000-000000000005', 'ob_admin', 'admin@openbeta.io', 'OpenBeta Admin', 'Database maintainer.', TRUE, TRUE);

-- ============================================================================
-- AREAS - Hierarchical structure
-- ============================================================================

-- Level 0: Countries
INSERT INTO areas (id, parent_id, name, path, path_tokens, grade_context, lat, lng, is_leaf) VALUES
    ('b0000000-0000-0000-0000-000000000001', NULL, 'USA', 'usa', ARRAY['USA'], 'US', 39.8283, -98.5795, FALSE),
    ('b0000000-0000-0000-0000-000000000002', NULL, 'France', 'fra', ARRAY['France'], 'FR', 46.2276, 2.2137, FALSE),
    ('b0000000-0000-0000-0000-000000000003', NULL, 'Spain', 'esp', ARRAY['Spain'], 'FR', 40.4637, -3.7492, FALSE);

-- Level 1: States/Regions (USA)
INSERT INTO areas (id, parent_id, name, path, path_tokens, lat, lng, is_leaf) VALUES
    ('b0000000-0000-0000-0001-000000000001', 'b0000000-0000-0000-0000-000000000001', 'California', 'usa.california', ARRAY['USA', 'California'], 36.7783, -119.4179, FALSE),
    ('b0000000-0000-0000-0001-000000000002', 'b0000000-0000-0000-0000-000000000001', 'Colorado', 'usa.colorado', ARRAY['USA', 'Colorado'], 39.5501, -105.7821, FALSE),
    ('b0000000-0000-0000-0001-000000000003', 'b0000000-0000-0000-0000-000000000001', 'Utah', 'usa.utah', ARRAY['USA', 'Utah'], 39.3210, -111.0937, FALSE);

-- Level 1: Regions (France)
INSERT INTO areas (id, parent_id, name, path, path_tokens, lat, lng, is_leaf) VALUES
    ('b0000000-0000-0000-0001-000000000010', 'b0000000-0000-0000-0000-000000000002', 'Fontainebleau', 'fra.fontainebleau', ARRAY['France', 'Fontainebleau'], 48.4047, 2.7013, FALSE);

-- Level 1: Regions (Spain)
INSERT INTO areas (id, parent_id, name, path, path_tokens, lat, lng, is_leaf) VALUES
    ('b0000000-0000-0000-0001-000000000020', 'b0000000-0000-0000-0000-000000000003', 'Catalonia', 'esp.catalonia', ARRAY['Spain', 'Catalonia'], 41.5912, 1.5209, FALSE);

-- Level 2: Major Areas (California)
INSERT INTO areas (id, parent_id, name, path, path_tokens, lat, lng, is_destination, is_leaf) VALUES
    ('b0000000-0000-0000-0002-000000000001', 'b0000000-0000-0000-0001-000000000001', 'Yosemite National Park', 'usa.california.yosemite', ARRAY['USA', 'California', 'Yosemite National Park'], 37.8651, -119.5383, TRUE, FALSE),
    ('b0000000-0000-0000-0002-000000000002', 'b0000000-0000-0000-0001-000000000001', 'Joshua Tree National Park', 'usa.california.joshua_tree', ARRAY['USA', 'California', 'Joshua Tree National Park'], 33.8734, -115.9010, TRUE, FALSE),
    ('b0000000-0000-0000-0002-000000000003', 'b0000000-0000-0000-0001-000000000001', 'Bishop', 'usa.california.bishop', ARRAY['USA', 'California', 'Bishop'], 37.3636, -118.3951, TRUE, FALSE);

-- Level 2: Major Areas (Colorado)
INSERT INTO areas (id, parent_id, name, path, path_tokens, lat, lng, is_destination, is_leaf) VALUES
    ('b0000000-0000-0000-0002-000000000010', 'b0000000-0000-0000-0001-000000000002', 'Boulder Canyon', 'usa.colorado.boulder_canyon', ARRAY['USA', 'Colorado', 'Boulder Canyon'], 40.0024, -105.4091, TRUE, FALSE),
    ('b0000000-0000-0000-0002-000000000011', 'b0000000-0000-0000-0001-000000000002', 'Clear Creek Canyon', 'usa.colorado.clear_creek', ARRAY['USA', 'Colorado', 'Clear Creek Canyon'], 39.7439, -105.4194, TRUE, FALSE);

-- Level 2: Fontainebleau sectors
INSERT INTO areas (id, parent_id, name, path, path_tokens, lat, lng, is_destination, is_leaf) VALUES
    ('b0000000-0000-0000-0002-000000000020', 'b0000000-0000-0000-0001-000000000010', 'Bas Cuvier', 'fra.fontainebleau.bas_cuvier', ARRAY['France', 'Fontainebleau', 'Bas Cuvier'], 48.4469, 2.6347, TRUE, FALSE);

-- Level 2: Catalonia areas
INSERT INTO areas (id, parent_id, name, path, path_tokens, lat, lng, is_destination, is_leaf) VALUES
    ('b0000000-0000-0000-0002-000000000030', 'b0000000-0000-0000-0001-000000000020', 'Siurana', 'esp.catalonia.siurana', ARRAY['Spain', 'Catalonia', 'Siurana'], 41.2564, 0.9364, TRUE, FALSE);

-- Level 3: Sub-areas / Walls (Yosemite)
INSERT INTO areas (id, parent_id, name, path, path_tokens, lat, lng, is_leaf, description) VALUES
    ('b0000000-0000-0000-0003-000000000001', 'b0000000-0000-0000-0002-000000000001', 'El Capitan', 'usa.california.yosemite.el_capitan', ARRAY['USA', 'California', 'Yosemite National Park', 'El Capitan'], 37.7340, -119.6377, TRUE, 'The most famous big wall in the world. 3000 feet of vertical granite.'),
    ('b0000000-0000-0000-0003-000000000002', 'b0000000-0000-0000-0002-000000000001', 'Half Dome', 'usa.california.yosemite.half_dome', ARRAY['USA', 'California', 'Yosemite National Park', 'Half Dome'], 37.7459, -119.5332, TRUE, 'Iconic dome with the Regular Northwest Face route.'),
    ('b0000000-0000-0000-0003-000000000003', 'b0000000-0000-0000-0002-000000000001', 'Camp 4 Boulders', 'usa.california.yosemite.camp4', ARRAY['USA', 'California', 'Yosemite National Park', 'Camp 4 Boulders'], 37.7424, -119.6024, TRUE, 'Historic bouldering area, birthplace of American bouldering.');

-- Level 3: Sub-areas (Joshua Tree)
INSERT INTO areas (id, parent_id, name, path, path_tokens, lat, lng, is_leaf, is_boulder, description) VALUES
    ('b0000000-0000-0000-0003-000000000010', 'b0000000-0000-0000-0002-000000000002', 'Hidden Valley', 'usa.california.joshua_tree.hidden_valley', ARRAY['USA', 'California', 'Joshua Tree National Park', 'Hidden Valley'], 33.9985, -116.1661, TRUE, FALSE, 'Classic JTree destination with routes and boulders.'),
    ('b0000000-0000-0000-0003-000000000011', 'b0000000-0000-0000-0002-000000000002', 'Real Hidden Valley', 'usa.california.joshua_tree.real_hidden_valley', ARRAY['USA', 'California', 'Joshua Tree National Park', 'Real Hidden Valley'], 34.0134, -116.1656, TRUE, TRUE, 'Boulder field with classics.');

-- Level 3: Sub-areas (Bishop)
INSERT INTO areas (id, parent_id, name, path, path_tokens, lat, lng, is_leaf, is_boulder, description) VALUES
    ('b0000000-0000-0000-0003-000000000020', 'b0000000-0000-0000-0002-000000000003', 'Happy Boulders', 'usa.california.bishop.happy', ARRAY['USA', 'California', 'Bishop', 'Happy Boulders'], 37.4019, -118.5614, TRUE, TRUE, 'World-class highballs and moderate classics.'),
    ('b0000000-0000-0000-0003-000000000021', 'b0000000-0000-0000-0002-000000000003', 'Sad Boulders', 'usa.california.bishop.sad', ARRAY['USA', 'California', 'Bishop', 'Sad Boulders'], 37.3987, -118.5578, TRUE, TRUE, 'More amazing volcanic bouldering.'),
    ('b0000000-0000-0000-0003-000000000022', 'b0000000-0000-0000-0002-000000000003', 'Buttermilks', 'usa.california.bishop.buttermilks', ARRAY['USA', 'California', 'Bishop', 'Buttermilks'], 37.3189, -118.5742, TRUE, TRUE, 'Home of the Grandpa Peabody and other highball testpieces.');

-- Level 3: Boulder Canyon walls
INSERT INTO areas (id, parent_id, name, path, path_tokens, lat, lng, is_leaf, description) VALUES
    ('b0000000-0000-0000-0003-000000000030', 'b0000000-0000-0000-0002-000000000010', 'The Dome', 'usa.colorado.boulder_canyon.the_dome', ARRAY['USA', 'Colorado', 'Boulder Canyon', 'The Dome'], 40.0012, -105.4234, TRUE, 'Steep sport climbing on bullet stone.');

-- Level 3: Fontainebleau boulders
INSERT INTO areas (id, parent_id, name, path, path_tokens, lat, lng, is_leaf, is_boulder, description) VALUES
    ('b0000000-0000-0000-0003-000000000040', 'b0000000-0000-0000-0002-000000000020', 'Circuit Orange', 'fra.fontainebleau.bas_cuvier.orange', ARRAY['France', 'Fontainebleau', 'Bas Cuvier', 'Circuit Orange'], 48.4471, 2.6351, TRUE, TRUE, 'Classic beginner-intermediate circuit.');

-- Level 3: Siurana walls
INSERT INTO areas (id, parent_id, name, path, path_tokens, lat, lng, is_leaf, description) VALUES
    ('b0000000-0000-0000-0003-000000000050', 'b0000000-0000-0000-0002-000000000030', 'La Trona', 'esp.catalonia.siurana.la_trona', ARRAY['Spain', 'Catalonia', 'Siurana', 'La Trona'], 41.2541, 0.9378, TRUE, 'The throne - steep tufa climbing.');

-- ============================================================================
-- CLIMBS
-- ============================================================================

-- El Capitan routes
INSERT INTO climbs (id, area_id, name, grade_yds, is_trad, is_aid, pitch_count, length_meters, fa, safety, description, created_by) VALUES
    ('c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0003-000000000001', 'The Nose', '5.14a', TRUE, FALSE, 31, 900, 'Warren Harding, Wayne Merry, George Whitmore (1958)', 'PG13', 'The most famous rock climb in the world. Originally aided over 47 days, now freed at 5.14a. The line follows the prominent prow of El Capitan.', 'a0000000-0000-0000-0000-000000000005'),
    ('c0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0003-000000000001', 'Freerider', '5.13a', TRUE, FALSE, 30, 900, 'Alex Huber (1998)', 'R', 'Classic free route on El Cap. Famously free soloed by Alex Honnold in 2017. Varied climbing with crack, face, and slab.', 'a0000000-0000-0000-0000-000000000005'),
    ('c0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0003-000000000001', 'Golden Gate', '5.13b', TRUE, FALSE, 28, 850, 'Tommy Caldwell (2000)', 'PG13', 'Another El Cap free climb, following a line left of The Nose.', 'a0000000-0000-0000-0000-000000000005'),
    ('c0000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0003-000000000001', 'Salathe Wall', '5.13b', TRUE, FALSE, 35, 900, 'Royal Robbins, Chuck Pratt, Tom Frost (1961)', 'R', 'One of the finest big wall free climbs in the world.', 'a0000000-0000-0000-0000-000000000005');

-- Half Dome routes
INSERT INTO climbs (id, area_id, name, grade_yds, is_trad, pitch_count, length_meters, fa, safety, description, created_by) VALUES
    ('c0000000-0000-0000-0000-000000000010', 'b0000000-0000-0000-0003-000000000002', 'Regular Northwest Face', '5.12a', TRUE, 23, 700, 'Royal Robbins, Mike Sherrick, Jerry Gallwas (1957)', 'PG13', 'The classic big wall route on Half Dome. Mostly moderate with crux pitches of thin face climbing.', 'a0000000-0000-0000-0000-000000000005');

-- Camp 4 boulder problems
INSERT INTO climbs (id, area_id, name, grade_vscale, is_boulder, fa, description, created_by) VALUES
    ('c0000000-0000-0000-0000-000000000020', 'b0000000-0000-0000-0003-000000000003', 'Midnight Lightning', 'V8', TRUE, 'Ron Kauk (1978)', 'The most famous boulder problem in the world. Iconic lightning bolt chalk mark. Steep moves on perfect granite.', 'a0000000-0000-0000-0000-000000000005'),
    ('c0000000-0000-0000-0000-000000000021', 'b0000000-0000-0000-0003-000000000003', 'Bachar Cracker', 'V4', TRUE, 'John Bachar', 'Perfect hand crack boulder problem.', 'a0000000-0000-0000-0000-000000000005'),
    ('c0000000-0000-0000-0000-000000000022', 'b0000000-0000-0000-0003-000000000003', 'Dominator', 'V12', TRUE, 'Dave Graham (2002)', 'Desperate roof climbing on the Columbia Boulder.', 'a0000000-0000-0000-0000-000000000005');

-- Joshua Tree routes
INSERT INTO climbs (id, area_id, name, grade_yds, is_trad, is_sport, bolts_count, fa, description, created_by) VALUES
    ('c0000000-0000-0000-0000-000000000030', 'b0000000-0000-0000-0003-000000000010', 'Double Cross', '5.7', TRUE, FALSE, 0, 'Unknown', 'Classic moderate crack climb. Great introduction to JTree climbing.', 'a0000000-0000-0000-0000-000000000005'),
    ('c0000000-0000-0000-0000-000000000031', 'b0000000-0000-0000-0003-000000000010', 'Intersection Rock - Right', '5.10b', FALSE, TRUE, 5, 'Unknown', 'Popular moderate sport route on the iconic Intersection Rock.', 'a0000000-0000-0000-0000-000000000005');

-- Joshua Tree boulders
INSERT INTO climbs (id, area_id, name, grade_vscale, is_boulder, fa, description, created_by) VALUES
    ('c0000000-0000-0000-0000-000000000035', 'b0000000-0000-0000-0003-000000000011', 'Stem Gem', 'V4', TRUE, 'Unknown', 'Classic JTree boulder problem with stemming and face moves.', 'a0000000-0000-0000-0000-000000000005'),
    ('c0000000-0000-0000-0000-000000000036', 'b0000000-0000-0000-0003-000000000011', 'White Lightning', 'V2', TRUE, 'Unknown', 'Fun warmup on positive holds.', 'a0000000-0000-0000-0000-000000000005');

-- Bishop boulder problems
INSERT INTO climbs (id, area_id, name, grade_vscale, is_boulder, fa, description, created_by) VALUES
    ('c0000000-0000-0000-0000-000000000040', 'b0000000-0000-0000-0003-000000000020', 'Happpy Boulder', 'V0', TRUE, 'Unknown', 'The namesake of the Happy Boulders. Fun moderate.', 'a0000000-0000-0000-0000-000000000005'),
    ('c0000000-0000-0000-0000-000000000041', 'b0000000-0000-0000-0003-000000000020', 'High Plains Drifter', 'V7', TRUE, 'Unknown', 'Classic highball with committing moves.', 'a0000000-0000-0000-0000-000000000005'),
    ('c0000000-0000-0000-0000-000000000042', 'b0000000-0000-0000-0003-000000000021', 'Evilution', 'V10', TRUE, 'Dave Graham', 'Desperate compression climbing.', 'a0000000-0000-0000-0000-000000000005'),
    ('c0000000-0000-0000-0000-000000000043', 'b0000000-0000-0000-0003-000000000022', 'Grandpa Peabody', 'V4', TRUE, 'Unknown', 'Famous highball. The proud line on the massive Grandpa boulder.', 'a0000000-0000-0000-0000-000000000005'),
    ('c0000000-0000-0000-0000-000000000044', 'b0000000-0000-0000-0003-000000000022', 'Mandala', 'V12', TRUE, 'Chris Sharma (2000)', 'One of the most famous hard boulder problems in the world. Perfect movement on the Grandma boulder.', 'a0000000-0000-0000-0000-000000000005'),
    ('c0000000-0000-0000-0000-000000000045', 'b0000000-0000-0000-0003-000000000022', 'The Swarm', 'V8', TRUE, 'Unknown', 'Technical crimping on steep stone.', 'a0000000-0000-0000-0000-000000000005');

-- Boulder Canyon sport routes
INSERT INTO climbs (id, area_id, name, grade_yds, is_sport, bolts_count, fa, description, created_by) VALUES
    ('c0000000-0000-0000-0000-000000000050', 'b0000000-0000-0000-0003-000000000030', 'Athlete''s Feat', '5.12c', TRUE, 8, 'Unknown', 'Classic steep sport route on The Dome.', 'a0000000-0000-0000-0000-000000000005'),
    ('c0000000-0000-0000-0000-000000000051', 'b0000000-0000-0000-0003-000000000030', 'Cosmosis', '5.13a', TRUE, 10, 'Unknown', 'Overhanging endurance test.', 'a0000000-0000-0000-0000-000000000005');

-- Fontainebleau boulders
INSERT INTO climbs (id, area_id, name, grade_font, is_boulder, fa, description, created_by) VALUES
    ('c0000000-0000-0000-0000-000000000060', 'b0000000-0000-0000-0003-000000000040', 'La Marie-Rose', '6A', TRUE, 'Unknown', 'The most famous boulder problem in Fontainebleau. Technical slab climbing.', 'a0000000-0000-0000-0000-000000000005'),
    ('c0000000-0000-0000-0000-000000000061', 'b0000000-0000-0000-0003-000000000040', 'L''Abbatoir', '7A', TRUE, 'Unknown', 'Steep and powerful.', 'a0000000-0000-0000-0000-000000000005');

-- Siurana sport routes
INSERT INTO climbs (id, area_id, name, grade_french, is_sport, bolts_count, fa, description, created_by) VALUES
    ('c0000000-0000-0000-0000-000000000070', 'b0000000-0000-0000-0003-000000000050', 'La Rambla', '9a+', TRUE, 12, 'Alexander Huber (2003)', 'One of the first 9a+ routes in the world. Sustained tufa climbing.', 'a0000000-0000-0000-0000-000000000005'),
    ('c0000000-0000-0000-0000-000000000071', 'b0000000-0000-0000-0003-000000000050', 'Rollito Sharma', '8a', TRUE, 8, 'Chris Sharma', 'Fun tufa climbing at a more accessible grade.', 'a0000000-0000-0000-0000-000000000005'),
    ('c0000000-0000-0000-0000-000000000072', 'b0000000-0000-0000-0003-000000000050', 'Estado Critico', '8b+', TRUE, 10, 'Unknown', 'Steep and technical.', 'a0000000-0000-0000-0000-000000000005');

-- ============================================================================
-- PITCHES (for multi-pitch routes)
-- ============================================================================

-- The Nose pitches (simplified - just a few key pitches)
INSERT INTO pitches (id, climb_id, pitch_number, grade_yds, is_trad, description) VALUES
    ('d0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 1, '5.10a', TRUE, 'Sickle Ledge pitch'),
    ('d0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000001', 14, '5.11c', TRUE, 'King Swing'),
    ('d0000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000001', 21, '5.14a', TRUE, 'Changing Corners - crux'),
    ('d0000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000001', 28, '5.12b', TRUE, 'Glowering Spot'),
    ('d0000000-0000-0000-0000-000000000005', 'c0000000-0000-0000-0000-000000000001', 31, '5.9', TRUE, 'Final headwall to summit');

-- ============================================================================
-- TICKS
-- ============================================================================

INSERT INTO ticks (id, user_id, climb_id, climb_name, grade, style, attempt_type, date_climbed, notes, source) VALUES
    -- Alex's ticks
    ('e0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000002', 'Freerider', '5.13a', 'Solo', 'Onsight', '2017-06-03', 'Free soloed in 3:56. Felt solid.', 'OB'),
    ('e0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000020', 'Midnight Lightning', 'V8', 'Boulder', 'Flash', '2015-05-10', 'Quick session before dinner.', 'OB'),

    -- Lynn's ticks
    ('e0000000-0000-0000-0000-000000000010', 'a0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000001', 'The Nose', '5.14a', 'Lead', 'Redpoint', '1993-09-19', 'First free ascent! It goes boys.', 'OB'),

    -- Adam's ticks
    ('e0000000-0000-0000-0000-000000000020', 'a0000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000070', 'La Rambla', '9a+', 'Lead', 'Redpoint', '2008-04-15', 'Finally!', 'OB'),
    ('e0000000-0000-0000-0000-000000000021', 'a0000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000044', 'Mandala', 'V12', 'Boulder', 'Flash', '2010-03-20', 'Good conditions.', 'OB'),

    -- Weekend warrior ticks
    ('e0000000-0000-0000-0000-000000000030', 'a0000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000030', 'Double Cross', '5.7', 'Lead', 'Onsight', '2024-01-15', 'My first trad lead! Hands were shaking.', 'OB'),
    ('e0000000-0000-0000-0000-000000000031', 'a0000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000036', 'White Lightning', 'V2', 'Boulder', 'Send', '2024-01-16', 'Took 5 tries but got it!', 'OB'),
    ('e0000000-0000-0000-0000-000000000032', 'a0000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000035', 'Stem Gem', 'V4', 'Boulder', 'Attempt', '2024-01-16', 'Project for next trip.', 'OB');

-- ============================================================================
-- MEDIA
-- ============================================================================

INSERT INTO media (id, user_id, url, width, height, format, size_bytes) VALUES
    ('f0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'https://example.com/media/freerider-solo.jpg', 1920, 1080, 'jpeg', 250000),
    ('f0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000002', 'https://example.com/media/nose-summit.jpg', 1600, 1200, 'jpeg', 180000),
    ('f0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000004', 'https://example.com/media/jtree-sunset.jpg', 2400, 1600, 'jpeg', 320000);

-- ============================================================================
-- ENTITY TAGS (photo tags)
-- ============================================================================

INSERT INTO entity_tags (id, media_id, climb_id, created_by) VALUES
    ('10000000-0000-0000-0000-000000000001', 'f0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001'),
    ('10000000-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000002');

INSERT INTO entity_tags (id, media_id, area_id, created_by) VALUES
    ('10000000-0000-0000-0000-000000000003', 'f0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0003-000000000010', 'a0000000-0000-0000-0000-000000000004');

-- ============================================================================
-- ORGANIZATIONS
-- ============================================================================

INSERT INTO organizations (id, org_type, display_name, website, email, donation_link, description, created_by) VALUES
    ('20000000-0000-0000-0000-000000000001', 'local_climbing_org', 'Access Fund', 'https://accessfund.org', 'info@accessfund.org', 'https://accessfund.org/donate', 'Protecting America''s climbing since 1991.', 'a0000000-0000-0000-0000-000000000005'),
    ('20000000-0000-0000-0000-000000000002', 'local_climbing_org', 'Friends of Joshua Tree', 'https://friendsofjosh.org', 'info@friendsofjosh.org', 'https://friendsofjosh.org/donate', 'Protecting Joshua Tree climbing access.', 'a0000000-0000-0000-0000-000000000005'),
    ('20000000-0000-0000-0000-000000000003', 'local_climbing_org', 'Bishop Area Climbers Coalition', 'https://bishopclimbing.org', 'info@bishopclimbing.org', 'https://bishopclimbing.org/donate', 'Stewardship and access in the Eastern Sierra.', 'a0000000-0000-0000-0000-000000000005');

-- ============================================================================
-- ORGANIZATION AREAS (which orgs cover which areas)
-- ============================================================================

INSERT INTO organization_areas (org_id, area_id, is_excluded) VALUES
    -- Access Fund covers major US areas
    ('20000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', FALSE),  -- USA

    -- Friends of JTree covers Joshua Tree
    ('20000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0002-000000000002', FALSE),  -- Joshua Tree

    -- BACC covers Bishop
    ('20000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0002-000000000003', FALSE);  -- Bishop

-- ============================================================================
-- UPDATE AREA STATS (run after seeding)
-- ============================================================================

-- Update total_climbs counts for all areas
WITH RECURSIVE area_tree AS (
    SELECT id, path FROM areas WHERE parent_id IS NULL
    UNION ALL
    SELECT a.id, a.path FROM areas a
    JOIN area_tree t ON a.parent_id = t.id
)
UPDATE areas a
SET total_climbs = (
    SELECT COUNT(*)
    FROM climbs c
    JOIN areas leaf ON c.area_id = leaf.id
    WHERE leaf.path <@ a.path
    AND c.deleted_at IS NULL
    AND leaf.deleted_at IS NULL
);

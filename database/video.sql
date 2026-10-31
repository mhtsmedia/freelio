-- ============================================================
-- Video i porteføljen
-- Lar frilansere laste opp video (MP4, MOV, WebM) på opptil 50 MB.
-- Kjør denne én gang i SQL Editor. Den kan kjøres flere ganger.
-- ============================================================

update storage.buckets
set file_size_limit = 52428800,
    allowed_mime_types = array['image/webp', 'image/jpeg', 'image/png', 'video/mp4', 'video/quicktime', 'video/webm']
where id = 'profiles';

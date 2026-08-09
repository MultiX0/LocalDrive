-- Media metadata, for the gallery.
--
-- Pixel dimensions let the client lay out a masonry grid without waiting for
-- every image to decode first. Without them the grid reflows visibly as
-- thumbnails arrive.
--
-- taken_at is the capture time out of the file's own metadata, which is a
-- genuinely different thing from created_at. A photo taken in 2019 and
-- uploaded today has created_at of today, and sorting a gallery by that puts
-- it at the top, which is wrong. It stays NULL when the file carries no
-- capture time, and the client falls back rather than inventing one.

ALTER TABLE nodes ADD COLUMN image_width  INTEGER NOT NULL DEFAULT 0;
ALTER TABLE nodes ADD COLUMN image_height INTEGER NOT NULL DEFAULT 0;
ALTER TABLE nodes ADD COLUMN taken_at     INTEGER;

-- the gallery's own listing: one owner's images, newest capture first, with
-- upload time as the tiebreak for anything that carries no capture time
CREATE INDEX idx_nodes_taken ON nodes (owner_id, taken_at DESC, created_at DESC);

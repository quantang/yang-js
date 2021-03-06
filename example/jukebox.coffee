# Example: jukebox module implementation
require('..')

module.exports = require('./jukebox.yang').bind {

  # bind behavior to config: false read-only elements
  '/jukebox/library/artist-count': -> @get('../artist')?.length ? 0
  '/jukebox/library/album-count':  -> @get('../artist/album')?.length ? 0
  '/jukebox/library/song-count':   -> @get('../artist/album/song')?.length ? 0
  
  '/play': (input) ->
    song = @get (
      "/jukebox/playlist['#{input.playlist}']/" +
      "song['#{input['song-number']}']"
    )
    unless song?
      @throw "selected song #{input['song-number']} not found in library"
    else if song.id instanceof Error
      @throw song.id
    else
      return "ok"
}

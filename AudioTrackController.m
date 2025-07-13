%{
AudioTrackController: Provides managment system for multiple tracks.
    Utalize .mat file storage with addSoundToLibrary()
    Add sounds repeatedly with minimal overhead with addSoundToTrack()
    Parse track scripts into audio data with parse() and parseAll()
    Manage playback dynamically with play()
    Control effects with clearTrack(), changeTrackGain(), changeTrackMute() and changeTrackPan()
%}
classdef AudioTrackController < handle

    %% Read only properties
    properties (SetAccess = private, GetAccess = public)
        tracks; % array of size tracks_number
        tracksNumber; % int8
        playbackPointer; % the current position of the playback pointer in buffers.
        duration; % in seconds
        bufferSize; % The ATC's buffer size
        isDone; % true/false, whether the ATC is finished playing
        storedSounds; % the stored sounds for the ATC
        libraryPath = "slib.mat" % the path to the storage file
        sampleRate; % the ATC's sample rate.
        bufferDuration; % duration in buffers
    end

    %% Methods for creation and playback
    methods (Access = public)
        %{ 
        AudioTrackController(tracks, duration, bufferSize, sampleRate): constructor for Audio Track Controllers.
            tracksNumber: number of tracks.
            duration: duration of composition in seconds.
            bufferSize: the buffer size to use.
            sampleRate: the sample rate to use.
        %}
        function thisATC = AudioTrackController(tracksNumber, duration, bufferSize, sampleRate)
            thisATC.tracksNumber = int8(tracksNumber); % set the number of tracks to reflect parameter input
            thisATC.tracks = Track.empty(thisATC.tracksNumber,0); % initialize the right number of empty tracks
            for i = 1:thisATC.tracksNumber % for each track, initialize a track object with the correct parrameters.
                thisATC.tracks(i) = Track(duration, bufferSize, sampleRate);
            end
            thisATC.playbackPointer = 1; % Set the playback pointer to 1 (the start).
            thisATC.duration = duration; % Set the duration to reflect parameter input.
            thisATC.bufferDuration = duration * sampleRate / bufferSize; % set the buffer duration based on sample rate, duration, and buffer size
            thisATC.bufferSize = bufferSize; % Set the buffer size to reflect parameter input
            thisATC.isDone = false; % Initialize isDone to false
            thisATC.sampleRate = sampleRate; % Set the sample rate to reflect parameter input
            thisATC.storedSounds = containers.Map(); % Initialize an empty map to store sounds.
            init_ = 0; % blank variable to store to path
            save(thisATC.libraryPath, "init_") % save black variable to path.
        end

        %{
        play(par?): Works like a fileReader. Returns the next available buffer of size bufferSize. 
            par: (optional) whether to perform track calculations in parallel or not.
        %}
        function buffer = play(thisATC, par)
            if nargin < 2  % set default value of par to false if not provided.
                par = false;
            end

            % looping behavior: if ATC is done and play() is called again,
            % set isDone to false again.
            if thisATC.isDone == true
                thisATC.isDone = false;
            end

            % preallocate a 3D array of track buffers. 
            trackBuffers = zeros(thisATC.bufferSize, 2, thisATC.tracksNumber);

            % populate 3D array using numerical for loop (alegedly faster than other methods)
            lTracks = thisATC.tracks;
            lPointer = thisATC.playbackPointer;
            if par % execute in paralel if specified.
                parfor i = 1:thisATC.tracksNumber
                    trackBuffers(:, :, i) = lTracks(i).play(lPointer);
                end
            else %execute normally otherwise.
                for i = 1:thisATC.tracksNumber
                    trackBuffers(:, :, i) = lTracks(i).play(lPointer);
                end
            end

            % vectorized sumation across the 3D matrix to give us the final signal
            buffer = sum(trackBuffers, 3);

            % increment playbackPontier
            thisATC.playbackPointer = thisATC.playbackPointer + 1;

            % looping behavior (reset playback pointer)
            if thisATC.playbackPointer > thisATC.bufferDuration
                thisATC.playbackPointer = 1;
                thisATC.isDone = true;
            end
        end   

        %{
        playTracks: Works like play but returns a 3d array to provide
                greater control over each tracks output to the user.
                Returns the next available buffer of size bufferSize, tracksize
        %}
        function buffers = playTracks(thisATC)
            % looping behavior: if ATC is done and play() is called again,
            % set isDone to false again.
            if thisATC.isDone == true
                thisATC.isDone = false;
            end

            % preallocate a 3D array of track buffers. 
            trackBuffers = zeros(thisATC.bufferSize, 2, thisATC.tracksNumber);

            % populate 3D array using numerical for loop (alegedly faster than other methods)
            lTracks = thisATC.tracks;
            lPointer = thisATC.playbackPointer;
            for i = 1:thisATC.tracksNumber
                trackBuffers(:, :, i) = lTracks(i).play(lPointer);
            end

            buffers = trackBuffers;

            % increment playbackPontier
            thisATC.playbackPointer = thisATC.playbackPointer + 1;

            % looping behavior (reset playback pointer)
            if thisATC.playbackPointer > thisATC.bufferDuration
                thisATC.playbackPointer = 1;
                thisATC.isDone = true;
            end
        end

        %{
        parse(track): Incorporates any changes made to the specified track into the playback stream.
            track:  Specifies a specific track to be parsed only. Best practice when 
                    only modifying a subset of available tracks to avoid overhead.
        %}
        function parse(thisATC, track)
            % call parse on the specified track.
            thisATC.tracks(track).parse();
        end

        %{
        parseAll(par?): Incorporates any changes made to all tracks into the playback stream. May be
                        computationally intensive. For realtime changes, it's better practice to use 
                        parse(track) for only the changed tracks instead. 
            par: (optional) whether to perform track calculations in parallel or not.
        %}
        function parseAll(thisATC, par)
            % set the default value of par to false when not provided
            if nargin < 2
                par = false;
            end
            
            % Loop through each track, calling parse on each.
            lTracks = thisATC.tracks;
            if par % Execute in parallel if specified.
                parfor i = 1:thisATC.tracksNumber
                    lTracks(i).parse(); % call parse on each track.
                end
            else % Otherwise execute in sequence. 
                for i = 1:thisATC.tracksNumber
                    lTracks(i).parse(); % call parse on each track.
                end
            end
        end
        
        %{
        resetPlayback(): Resets the playback to the start of the ATC loop.
        %}
        function resetPlayback(thisATC)
            % set the playback pointer to 1, effectively restarting playback.
            thisATC.playbackPointer = 1;
        end
    end

    %% Methods for interfacing with the Sound Library
    methods (Access = public)

         %{
        addSoundToLibrary(): Adds a sound based on provided samples to the audio track controllers stored library of available
                             sounds, which can then be placed in tracks as needed.
            name: the name of the sound file in the ATC system. Must be unique.
            audioData: the samples to be stored into the library.

        Warning: the sound library is stored in slib.matt in the local directory. Running multiple
            audio track controllers in the same directory will all share the same slib.matt, which
            is unsupported, not recomended, and may result in bad things happening. 
        %}
        function addSamplesToLibrary(thisATC, name, audioData)
            % check for conflicting namespace
            if isKey(thisATC.storedSounds, name)
                warning("Sound name %s already exits. Please choose a unique name.", name);
                return;
            end

            % store the loaded file into the selected namespace. 
            soundStruct.(name) = audioData;

            % Load existing data once, update, and save back
            if isfile(thisATC.libraryPath) % check file exists.
                existingSounds = load(thisATC.libraryPath); % load file into memory
                existingSounds.(name) = audioData; % add the audioData to the given namespace
                save(thisATC.libraryPath, '-struct', 'existingSounds', '-nocompression'); % save the file to disk.
            else % create file if it doesn't exist.
                save(thisATC.libraryPath, '-struct', 'soundStruct', '-nocompression');
            end

            % add sound to keyset in memory.
            thisATC.storedSounds(name) = true;

            disp(['Sound "' name '" added successfully.']);
        end

        %{
        addSoundToLibrary(): Adds a sound from file to the audio track controllers stored library of available
                             sounds, which can then be placed in tracks as needed.
            name: the name of the sound file in the ATC system. Must be unique.

        Warning: the sound library is stored in slib.matt in the local directory. Running multiple
            audio track controllers in the same directory will all share the same slib.matt, which
            is unsupported, not recomended, and may result in bad things happening. 
        %}
        function addSoundToLibrary(thisATC, name)

            % check for conflicting namespace
            if isKey(thisATC.storedSounds, name)
                warning("Sound name %s already exits. Please choose a unique name.", name);
                return;
            end

            % select a file from disk and load it into memory
            [filename, pathname] = uigetfile('*.*');
            filepath = fullfile(pathname, filename);
            [audioData, fs] = audioread(filepath);

            % store the loaded file into the selected namespace
            soundStruct.(name) = audioData;
            % Load existing data once, update, and save back
            if isfile(thisATC.libraryPath) % check if the file exists
                existingSounds = load(thisATC.libraryPath); % load file into memory
                existingSounds.(name) = audioData; % add the audioData to the given namespace
                save(thisATC.libraryPath, '-struct', 'existingSounds', '-nocompression'); % save back to file
            else % create it if it doesn't exist.
                save(thisATC.libraryPath, '-struct', 'soundStruct', '-nocompression'); % save file
            end
            
            % add sound to keyset in memory
            thisATC.storedSounds(name) = true;

            disp(['Sound "' name '" added successfully.']);
        end
    end

    %% Methods for composing in tracks.
    methods (Access = public)
        %{
        addSoundToTrack(sound, track, start): Provides functionality to add sounds from your library
            to a tracks script. Follow with parse(track) to incorporate outstanding changes. 
            sound: the name of the sound to add (from your existing library).
            track: the track to add the sound to.
            start: the start time in ms where you want the sound to begin.
        %}
        function addSoundToTrack(thisATC, sound, track, start)
            thisATC.tracks(track).addSound(sound, start); % call add sound on the given track.
        end

        %{
        clearTrack(track): resets the track back to silence. 
            track: the track to clear. 
        %}
        function clearTrack(thisATC, track)
            thisATC.tracks(track).clear(); % call clear on the given track.
        end

        %{
        changeTrackGain(track, newGain): changes the specified tracks gain.
            track: the track to adjust.
            newGain: the gain value in delta dB.
        %}
        function changeTrackGain(thisATC, track, newGain)
            thisATC.tracks(track).changeGain(newGain); % call changeGain on the given track.
        end

        %{
        changeTrackPan(track, newPan): changes the specified tracks panning coeficient.
            track: the track to adjust.
            newPan: the pan value from -1 (L) to 1 (R). 0 is neutral. 
        %}
        function changeTrackPan(thisATC, track, newPan)
            thisATC.tracks(track).changePan(newPan); % call changePan on the given track.
        end

        %{
        changeTrackMute(track, newMute): toggles mute for the specified track.
            track: the track to adjust.
            newMute: the mute value (true or false).
        %}
        function changeTrackMute(thisATC, track, newMute)
            thisATC.tracks(track).changeMute(newMute); % call changeMute on the given track.
        end
    end
end

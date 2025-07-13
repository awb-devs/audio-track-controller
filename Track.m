%{
Track: Manages values, script, audioData, and playback for a single track.
    Add sounds repeatedly to script with minimal overhead with addSound()
    Parse track scripts into audio data with parse()
    Manage playback dynamically with play()
    Control effects with clear(), changeGain(), changeMute() and changePan()
%}
classdef Track < handle

    %% Read only properties
    properties (SetAccess = private, GetAccess = public) 
        gain = 1.0; % track gain
        leftGain; % track left channel gain
        rightGain; % track right channel gain
        pan = 0.0; % track panning.
        script; % track script (saves event information for the track in the form of sound namespace (from the library) and starttime.
        audioBuffer; % current parsed audiobuffer
        bufferSize; % track buffer size. Should be synced with the ATC buffer size.
        duration; % track durration. Should be synced with the ATC duration.
        sampleRate; % track sample rate. Should be synced with the ATC sampleRate.
        bufferDuration; % track buffer Duration, should be synced with the ATC. 
        libraryPath = "slib.mat" % track library path, should be synced with the ATC.
        mute = false; % track mute (true = muted, false = live). 
    end

    %% Methods for creation and playback
    methods (Access = public)

        %{ 
        Track(duration, bufferSize, sampleRate): constructor for Tracks.
            duration: duration of composition in seconds.
            bufferSize: the buffer size to use.
            sampleRate: the sample rate to use.
        %}
        function thisTrack = Track(duration, bufferSize, sampleRate)
            thisTrack.script = {}; % initialize the script to empty.
            thisTrack.duration = duration; % set duration as provided.
            thisTrack.bufferSize = bufferSize; % set buffer size as provided.
            thisTrack.sampleRate = sampleRate; % set sample rate as provided.
            thisTrack.bufferDuration = duration * sampleRate / bufferSize; % calculate buffer duration.
            thisTrack.audioBuffer = zeros(thisTrack.bufferDuration * bufferSize, 2); % initialize audiobuffer to zeroes (silent track). 
            % Apply Panning (Constant Power Pan Law)
            % Calculate gains for left and right channels
            thisTrack.leftGain = cos((pi/4) * (1 + thisTrack.pan)) * thisTrack.gain; % calculate left gain. 
            thisTrack.rightGain = sin((pi/4) * (1 + thisTrack.pan)) * thisTrack.gain; % calculate right gain.
        end

        %{
        play(playbackPointer): returns the selected slice of audio data starting at playbackPointer
            and sized at a single buffer's size. Augmentations such as gain and panning are applied
            at this step.
            playbackPointer: the intended starting point in buffers. 
        %}
        function buffer = play(thisTrack, playbackPointer)
            % return buffer of zeros if this track is muted
            if thisTrack.mute
                buffer = zeros(thisTrack.bufferSize, 2); % silence returned if track is muted.
                return;
            end

            % calculate start and end indexes
            first = playbackPointer * thisTrack.bufferSize - thisTrack.bufferSize + 1; % 1 based indexing strikes again
            last = first + thisTrack.bufferSize - 1; % I hate it here

            if last > size(thisTrack.audioBuffer, 1) % error checking for mismatched buffer sizes.
                error("Requested buffer is out of range");
            end

            % index into the overall audioBuffer and grab the goods
            buffer = thisTrack.audioBuffer(first:last, :);
            % buffer = signal * thisTrack.gain;
            
            % Apply the calculated gains to the buffer
            buffer(:, 1) = buffer(:, 1) * thisTrack.leftGain;  % Left Channel
            buffer(:, 2) = buffer(:, 2) * thisTrack.rightGain; % Right Channel
        end

        %{
        parse(): parses this tracks script from a list of sounds and onsets to an audio data buffer.
            Loads each sound from the .mat library. 
        %}
        function parse(thisTrack)
            for i = 1:length(thisTrack.script)
                % skip if nothing has changed
                if thisTrack.script{i}.changed == false 
                    continue;
                end
                
                % load audio data from the library
                soundName = thisTrack.script{i}.name; % get namespace
                loadedDataStruct = load(thisTrack.libraryPath, "-mat", soundName); % load file into memory
                loadedData = loadedDataStruct.(soundName); % get the data from the correct namespace. 

                % calculate the start sample based on the given event start
                % time. 
                startSample = round(thisTrack.script{i}.start / 1000 * thisTrack.sampleRate) + 1;
                
                if startSample > length(thisTrack.audioBuffer) % make sure that the start sample is not out of bounds for the buffer length.
                    warning(['Start time for ', thisTrack.script{i}.name ' is out of bounds']);
                    continue;
                end

                % calculate the end sample based on the start sample. 
                endSample = startSample + size(loadedData, 1) - 1;

                if endSample > length(thisTrack.audioBuffer)
                    endSample = length(thisTrack.audioBuffer);
                    loadedData = loadedData(1:(endSample - startSample + 1), :);
                end

                % Sum the audio data into the audio buffer
                thisTrack.audioBuffer(startSample:endSample, :) = ... 
                    thisTrack.audioBuffer(startSample:endSample, :) + loadedData;
                
                % Set changed = false
                thisTrack.script{i}.changed = false;
            end
        end
    end

    %% Methods for composition
    methods (Access = public)

        %{
        addSound(sound, start): Provides functionality to add sounds from your library
            to this tracks script. Follow with parse() to incorporate outstanding changes. 
            sound: the name of the sound to add (from your existing library).
            start: the start time in ms where you want the sound to begin.
        %}
        function addSound(thisTrack, sound, start) 
            if start/1000 > thisTrack.duration
                error("Requested start time past file duration")
            end
            
            % create a new structure to pass into the script
            sound = struct('name', sound, 'start', start, 'changed', true);

            % add the structure as the last item in the script
            thisTrack.script{end+1} = sound;
        end

        %{
        clearTrack(): resets this track back to silence.
        %}
        function clear(thisTrack)
            thisTrack.audioBuffer = zeros(thisTrack.bufferDuration * thisTrack.bufferSize, 2);
        end

        %{
        changeGain(newGain): changes this tracks gain. will also recompute panning.
            newGain: the gain value in delta dB.
        %}
        function changeGain(thisTrack, newGain)
            thisTrack.gain = 10^(newGain / 20);
            % Apply Panning (Constant Power Pan Law)
            % Calculate gains for left and right channels
            thisTrack.leftGain = cos((pi/4) * (1 + thisTrack.pan)) * thisTrack.gain;
            thisTrack.rightGain = sin((pi/4) * (1 + thisTrack.pan)) * thisTrack.gain;
        end

        %{
        changePan(newPan): changes this tracks panning coeficient. 
            will also recompute panning gains.
            newPan: the pan value from -1 (L) to 1 (R). 0 is neutral. 
        %}
        function changePan(thisTrack, newPan)
            thisTrack.pan = newPan;
            % Apply Panning (Constant Power Pan Law)
            % Calculate gains for left and right channels
            thisTrack.leftGain = cos((pi/4) * (1 + thisTrack.pan)) * thisTrack.gain;
            thisTrack.rightGain = sin((pi/4) * (1 + thisTrack.pan)) * thisTrack.gain;
        end

        %{
        changeMute(newMute): toggles mute for this track.
            newMute: the mute value (true or false).
        %}
        function changeMute(thisTrack, newMute)
            thisTrack.mute = newMute;
        end
    end
end
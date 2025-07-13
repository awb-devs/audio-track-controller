%{
Demonstration script for simple ATC workflows. 
%}
function TCDemoScript()

    % Set workspace
    clc; close; clear all
    audiodevreset;

    % Important Parameters
    sr = 44100;
    bs = 1024;
    dur = 30;

    % System Objects
    deviceWriter = audioDeviceWriter( ...
        'SampleRate', sr, ...
        'SupportVariableSizeInput', true, ...
        'BufferSize', bs ...
    );

    scope1 = timescope( ...
        'SampleRate',[sr], ...
        'TimeSpan',0.1, ...
        'BufferLength', 512, ...
        'YLimits',[-1,1], ...
        'TimeSpanOverrunAction',"Scroll",...
        "LayoutDimensions",[1 1] ...
        );

    % Initialize Audio Track Controller
    ATC = AudioTrackController(1, dur, bs, sr);

    % Add Sound to Library
    ATC.addSoundToLibrary("foo");
    whos("-file", ATC.libraryPath)

    % Add Sound to Track
    ATC.addSoundToTrack("foo", 1, 0);

    % Parse script to audio
    ATC.parse(1);

    % FileReader style playback
    while ~ATC.isDone
        signal = ATC.play();
        deviceWriter(signal);
        scope1(signal)
        drawnow
    end
end
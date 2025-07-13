%{
An interactive application designed to demonstrate key functionality of the AudioTrackController.
Intentionally barebones implementation, designed to be (as much as possible) a simple UI wrapper
which calls functions from it's AudioTrackController.
%}
classdef ATCInteractiveAppDemo_exported < matlab.apps.AppBase

    %% Properties that correspond to app components
    properties (Access = public)
        UIFigure                     matlab.ui.Figure
        GridLayout                   matlab.ui.container.GridLayout
        Track4Panel                  matlab.ui.container.Panel
        GridLayout2_8                matlab.ui.container.GridLayout
        Track4EnabledSwitch          matlab.ui.control.Switch
        TrackEnabledSwitch_2Label_3  matlab.ui.control.Label
        Track4ClearButton            matlab.ui.control.Button
        Track4GainSlider             matlab.ui.control.Slider
        Track4PanKnob                matlab.ui.control.Knob
        Track4ParseButton            matlab.ui.control.Button
        Track3Panel                  matlab.ui.container.Panel
        GridLayout2_7                matlab.ui.container.GridLayout
        Track3EnabledSwitch          matlab.ui.control.Switch
        TrackEnabledSwitch_2Label_2  matlab.ui.control.Label
        Track3ClearButton            matlab.ui.control.Button
        Track3GainSlider             matlab.ui.control.Slider
        Track3PanKnob                matlab.ui.control.Knob
        Track3ParseButton            matlab.ui.control.Button
        Track2Panel                  matlab.ui.container.Panel
        GridLayout2_6                matlab.ui.container.GridLayout
        Track2EnabledSwitch          matlab.ui.control.Switch
        TrackEnabledSwitch_2Label    matlab.ui.control.Label
        Track2ClearButton            matlab.ui.control.Button
        Track2GainSlider             matlab.ui.control.Slider
        Track2PanKnob                matlab.ui.control.Knob
        Track2ParseButton            matlab.ui.control.Button
        MasterPanel                  matlab.ui.container.Panel
        GridLayout2_5                matlab.ui.container.GridLayout
        MasterGainSlider             matlab.ui.control.Slider
        MasterRightMeter             audio.ui.control.Meter
        MasterLeftMeter              audio.ui.control.Meter
        ControlsPanel                matlab.ui.container.Panel
        GridLayout6                  matlab.ui.container.GridLayout
        astl_Sound_Name              matlab.ui.control.EditField
        TimeLabel                    matlab.ui.control.Label
        AddSoundButton               matlab.ui.control.Button
        AddSoundDropDownLabel_6      matlab.ui.control.Label
        RepeatQuantity               matlab.ui.control.NumericEditField
        RepeatEvery                  matlab.ui.control.NumericEditField
        AddSoundDropDownLabel_5      matlab.ui.control.Label
        AddSoundDropDownLabel_4      matlab.ui.control.Label
        RepeatSwitch                 matlab.ui.control.Switch
        AddSoundDropDownLabel_3      matlab.ui.control.Label
        AddSoundStartTimeEditField   matlab.ui.control.NumericEditField
        AddSoundDropDownLabel_2      matlab.ui.control.Label
        TrackDropDown                matlab.ui.control.DropDown
        AddSoundDropDown             matlab.ui.control.DropDown
        AddSoundDropDownLabel        matlab.ui.control.Label
        AddSoundtoLibraryButton      matlab.ui.control.Button
        PlaybackSwitch               matlab.ui.control.Switch
        Track1Panel                  matlab.ui.container.Panel
        GridLayout2                  matlab.ui.container.GridLayout
        Track1EnabledSwitch          matlab.ui.control.Switch
        TrackEnabledSwitchLabel      matlab.ui.control.Label
        Track1ClearButton            matlab.ui.control.Button
        Track1GainSlider             matlab.ui.control.Slider
        Track1PanKnob                matlab.ui.control.Knob
        Track1ParseButton            matlab.ui.control.Button
        WaveformAxes                 matlab.ui.control.UIAxes
    end


    %% Public properties that correspond to the Simulink model
    properties (Access = public, Transient)
        Simulation simulink.Simulation
    end

    %% Private properties
    properties (Access = private)
        ATC;
        deviceWriter;
        playbackTimer;
        plotTime;
        augmenter;
    end
    

    %% Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            sr = 44100;
            bs = 1024;
            dur = 40;
            tracksNumber = 4;
        
            % Initialize AudioTrackController
            app.ATC = AudioTrackController(tracksNumber, dur, bs, sr);
        
            % Initialize Audio Device Writer
            app.deviceWriter = audioDeviceWriter( ...
                'SampleRate', sr, ...
                'SupportVariableSizeInput', true, ...
                'BufferSize', bs, ...
                'Device', 'Default' ...
            );

            % Initialize audioDataAugmenter in startupFcn
            app.augmenter = audioDataAugmenter( ...
                "AugmentationMode","sequential", ...
                "AugmentationParameterSource",'specify',...
                "NumAugmentations",1, ...
                ...
                "ApplyTimeStretch",false, ...
                "SpeedupFactor", 0, ...
                ...
                "ApplyPitchShift",false, ...
                "SemitoneShift",0, ...
                ...
                "ApplyVolumeControl",true, ...
                "VolumeGain",0, ...
                ...
                "ApplyAddNoise",false, ...
                "SNR",0,...
                ...
                "ApplyTimeShift",false, ...
                "TimeShift", 0 ...
            );
        
            % Update the AddSoundDropDown with the existing sounds in the library
            if isfile(app.ATC.libraryPath)
                soundLibrary = load(app.ATC.libraryPath);
                app.AddSoundDropDown.Items = fieldnames(soundLibrary);
            else
                app.AddSoundDropDown.Items = {'No Sounds Available'};
            end

            % Calculate the time vector for one buffer
            app.plotTime = (0:(app.ATC.bufferSize - 1)) / app.ATC.sampleRate;
        end

        % Value changed function: PlaybackSwitch
        function PlaybackSwitchValueChanged(app, event)
            isPlaying = app.PlaybackSwitch.Value;
        
            updateCounter = 0;
            while isPlaying == "On"
                % Get the next audio buffer
                signal = app.ATC.play();

                % Apply Gain using augmenter
                app.augmenter.VolumeGain = app.MasterGainSlider.Value;
                signal = augment(app.augmenter, signal);
                signal = cell2mat(signal.Audio);

        
                % Play the audio buffer
                app.deviceWriter(signal);


                % Increment the counter
                updateCounter = updateCounter + 1;
                
                % Only update meters every 5 buffers
                if mod(updateCounter, 5) == 0

                    % Plot the waveform on the axes
                    plot(app.WaveformAxes, app.plotTime, signal(:, 1));  % Plot the left channel


                    % Calculate peak value for each channel
                    leftChannelPeak = max(abs(signal(:, 1)));
                    rightChannelPeak = max(abs(signal(:, 2)));
                
                    % Convert peak to dB
                    leftChanneldB = 20 * log10(leftChannelPeak);
                    rightChanneldB = 20 * log10(rightChannelPeak);
                
                    % Handle -Inf when peak is zero (silence)
                    if ~isfinite(leftChanneldB)
                        leftChanneldB = -Inf;
                    end
                    if ~isfinite(rightChanneldB)
                        rightChanneldB = -Inf;
                    end
                
                    %  Update the Meters
                    app.MasterLeftMeter.Value = leftChanneldB;
                    app.MasterRightMeter.Value = rightChanneldB;
                end
           
                % Update the elapsed time display
                elapsedTime = double(app.ATC.playbackPointer * app.ATC.bufferSize / app.ATC.sampleRate);
                minutes = floor(elapsedTime / 60);
                seconds = floor(mod(elapsedTime, 60));
                milliseconds = round(mod(elapsedTime, 1) * 1000);
                formattedTime = sprintf('%02d:%02d.%03d', minutes, seconds, milliseconds);
                app.TimeLabel.Text = formattedTime;
        
                % Update value of isPlaying
                isPlaying = app.PlaybackSwitch.Value;
        
                % Draw UI updates
                drawnow;
            end
        end

        % Button pushed function: AddSoundtoLibraryButton
        function AddSoundtoLibraryButtonPushed(app, event)
            app.ATC.addSoundToLibrary(app.astl_Sound_Name.Value);
            if isfile(app.ATC.libraryPath)
                soundLibrary = load(app.ATC.libraryPath);
                app.AddSoundDropDown.Items = fieldnames(soundLibrary);
            else
                app.AddSoundDropDown.Items = {'No Sounds Available'};
            end
        end

        % Button pushed function: AddSoundButton
        function AddSoundButtonPushed(app, event)
            start = app.AddSoundStartTimeEditField.Value * 1000;
            track = app.TrackDropDown.ValueIndex;
            sound = app.AddSoundDropDown.Value;
            app.ATC.addSoundToTrack(sound, track, start);
            if app.RepeatSwitch.Value == "On"
                rptEvery = app.RepeatEvery.Value;
                for i=1:app.RepeatQuantity.Value
                    start = start + rptEvery * 1000;
                    app.ATC.addSoundToTrack(sound, track, start);
                end
            end
        end

        % Button pushed function: Track1ParseButton
        function Track1ParseButtonPushed(app, event)
            app.ATC.parse(1);
        end

        % Button pushed function: Track1ClearButton
        function Track1ClearButtonPushed(app, event)
            app.ATC.clearTrack(1);
        end

        % Value changed function: Track1GainSlider
        function Track1GainSliderValueChanged(app, event)
            value = app.Track1GainSlider.Value;
            app.ATC.changeTrackGain(1, value);
        end

        % Value changed function: Track1PanKnob
        function Track1PanKnobValueChanged(app, event)
            value = app.Track1PanKnob.Value;
            app.ATC.changeTrackPan(1, value);
        end

        % Value changed function: Track1EnabledSwitch
        function Track1EnabledSwitchValueChanged(app, event)
            value = app.Track1EnabledSwitch.Value;
            if value == "On"
                mute = false;
            else
                mute = true;
            end

            app.ATC.changeTrackMute(1, mute);
        end

        % Button pushed function: Track2ClearButton
        function Track2ClearButtonPushed(app, event)
            app.ATC.clearTrack(2);
        end

        % Value changed function: Track2EnabledSwitch
        function Track2EnabledSwitchValueChanged(app, event)
            value = app.Track2EnabledSwitch.Value;
            if value == "On"
                mute = false;
            else
                mute = true;
            end

            app.ATC.changeTrackMute(2, mute);
        end

        % Value changed function: Track2GainSlider
        function Track2GainSliderValueChanged(app, event)
            value = app.Track2GainSlider.Value;
            app.ATC.changeTrackGain(2, value);
        end

        % Value changed function: Track2PanKnob
        function Track2PanKnobValueChanged(app, event)
            value = app.Track2PanKnob.Value;
            app.ATC.changeTrackPan(2, value);
        end

        % Button pushed function: Track2ParseButton
        function Track2ParseButtonPushed(app, event)
            app.ATC.parse(2);
        end

        % Value changed function: Track4EnabledSwitch
        function Track4EnabledSwitchValueChanged(app, event)
            value = app.Track4EnabledSwitch.Value;
            if value == "On"
                mute = false;
            else
                mute = true;
            end

            app.ATC.changeTrackMute(4, mute);
        end

        % Button pushed function: Track4ClearButton
        function Track4ClearButtonPushed(app, event)
            app.ATC.clearTrack(4);
        end

        % Value changed function: Track4PanKnob
        function Track4PanKnobValueChanged(app, event)
            value = app.Track4PanKnob.Value;
            app.ATC.changeTrackPan(4, value);
        end

        % Button pushed function: Track4ParseButton
        function Track4ParseButtonPushed(app, event)
            app.ATC.parse(4);
        end

        % Value changed function: Track3EnabledSwitch
        function Track3EnabledSwitchValueChanged(app, event)
            value = app.Track3EnabledSwitch.Value;
            if value == "On"
                mute = false;
            else
                mute = true;
            end

            app.ATC.changeTrackMute(3, mute);
        end

        % Button pushed function: Track3ClearButton
        function Track3ClearButtonPushed(app, event)
            app.ATC.clearTrack(3);
        end

        % Value changed function: Track3GainSlider
        function Track3GainSliderValueChanged(app, event)
            value = app.Track3GainSlider.Value;
            app.ATC.changeTrackGain(3, value);
        end

        % Value changed function: Track3PanKnob
        function Track3PanKnobValueChanged(app, event)
            value = app.Track3PanKnob.Value;
            app.ATC.changeTrackPan(3, value);
        end

        % Button pushed function: Track3ParseButton
        function Track3ParseButtonPushed(app, event)
            app.ATC.parse(3);
        end
    end

    %% Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [0 0 1512 982];
            app.UIFigure.Name = 'MATLAB App';

            % Create GridLayout
            app.GridLayout = uigridlayout(app.UIFigure);
            app.GridLayout.ColumnWidth = {'1x', '1x', '1x', '1x', '1x'};
            app.GridLayout.RowHeight = {'1x', '1x', '1x', '1x', '1x', '1x', '1x', '1x', '1x', '1x'};

            % Create WaveformAxes
            app.WaveformAxes = uiaxes(app.GridLayout);
            xlabel(app.WaveformAxes, 'Time (s)')
            ylabel(app.WaveformAxes, 'Amplitude')
            zlabel(app.WaveformAxes, 'Z')
            app.WaveformAxes.FontName = 'Comic Sans MS';
            app.WaveformAxes.YLim = [-1 1];
            app.WaveformAxes.XTick = [0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1];
            app.WaveformAxes.Layout.Row = [7 10];
            app.WaveformAxes.Layout.Column = [1 5];

            % Create Track1Panel
            app.Track1Panel = uipanel(app.GridLayout);
            app.Track1Panel.TitlePosition = 'centertop';
            app.Track1Panel.Title = 'Track 1';
            app.Track1Panel.Layout.Row = [3 6];
            app.Track1Panel.Layout.Column = 1;
            app.Track1Panel.FontName = 'Comic Sans MS';
            app.Track1Panel.FontSize = 18;

            % Create GridLayout2
            app.GridLayout2 = uigridlayout(app.Track1Panel);
            app.GridLayout2.ColumnWidth = {'1x', '1x', '1x', '1x'};
            app.GridLayout2.RowHeight = {'1x', '1x', '1x', '1x', '1x'};

            % Create Track1ParseButton
            app.Track1ParseButton = uibutton(app.GridLayout2, 'push');
            app.Track1ParseButton.ButtonPushedFcn = createCallbackFcn(app, @Track1ParseButtonPushed, true);
            app.Track1ParseButton.BackgroundColor = [1 1 1];
            app.Track1ParseButton.FontName = 'Comic Sans MS';
            app.Track1ParseButton.Layout.Row = 1;
            app.Track1ParseButton.Layout.Column = [3 4];
            app.Track1ParseButton.Text = 'Parse';

            % Create Track1PanKnob
            app.Track1PanKnob = uiknob(app.GridLayout2, 'continuous');
            app.Track1PanKnob.Limits = [-1 1];
            app.Track1PanKnob.ValueChangedFcn = createCallbackFcn(app, @Track1PanKnobValueChanged, true);
            app.Track1PanKnob.Layout.Row = [3 4];
            app.Track1PanKnob.Layout.Column = [2 3];
            app.Track1PanKnob.FontName = 'Comic Sans MS';

            % Create Track1GainSlider
            app.Track1GainSlider = uislider(app.GridLayout2);
            app.Track1GainSlider.Limits = [-12 12];
            app.Track1GainSlider.MajorTicks = [-12 -9 -6 -3 0 3 6 9 12];
            app.Track1GainSlider.MajorTickLabels = {'-12', '-9', '-6', '-3', '0', '+3', '+6', '+9', '12'};
            app.Track1GainSlider.ValueChangedFcn = createCallbackFcn(app, @Track1GainSliderValueChanged, true);
            app.Track1GainSlider.FontName = 'Comic Sans MS';
            app.Track1GainSlider.Layout.Row = 5;
            app.Track1GainSlider.Layout.Column = [1 4];

            % Create Track1ClearButton
            app.Track1ClearButton = uibutton(app.GridLayout2, 'push');
            app.Track1ClearButton.ButtonPushedFcn = createCallbackFcn(app, @Track1ClearButtonPushed, true);
            app.Track1ClearButton.FontName = 'Comic Sans MS';
            app.Track1ClearButton.Layout.Row = 1;
            app.Track1ClearButton.Layout.Column = [1 2];
            app.Track1ClearButton.Text = 'Clear';

            % Create TrackEnabledSwitchLabel
            app.TrackEnabledSwitchLabel = uilabel(app.GridLayout2);
            app.TrackEnabledSwitchLabel.HorizontalAlignment = 'center';
            app.TrackEnabledSwitchLabel.FontName = 'Comic Sans MS';
            app.TrackEnabledSwitchLabel.Layout.Row = 2;
            app.TrackEnabledSwitchLabel.Layout.Column = [1 2];
            app.TrackEnabledSwitchLabel.Text = 'Track Enabled';

            % Create Track1EnabledSwitch
            app.Track1EnabledSwitch = uiswitch(app.GridLayout2, 'slider');
            app.Track1EnabledSwitch.ValueChangedFcn = createCallbackFcn(app, @Track1EnabledSwitchValueChanged, true);
            app.Track1EnabledSwitch.FontName = 'Comic Sans MS';
            app.Track1EnabledSwitch.Layout.Row = 2;
            app.Track1EnabledSwitch.Layout.Column = [3 4];
            app.Track1EnabledSwitch.Value = 'On';

            % Create ControlsPanel
            app.ControlsPanel = uipanel(app.GridLayout);
            app.ControlsPanel.Title = 'Controls';
            app.ControlsPanel.Layout.Row = [1 2];
            app.ControlsPanel.Layout.Column = [1 5];
            app.ControlsPanel.FontName = 'Comic Sans MS';
            app.ControlsPanel.FontSize = 18;

            % Create GridLayout6
            app.GridLayout6 = uigridlayout(app.ControlsPanel);
            app.GridLayout6.ColumnWidth = {'1x', '1x', '1x', '1x', '1x', '1x', '1x', '1x', '1x'};

            % Create PlaybackSwitch
            app.PlaybackSwitch = uiswitch(app.GridLayout6, 'slider');
            app.PlaybackSwitch.ValueChangedFcn = createCallbackFcn(app, @PlaybackSwitchValueChanged, true);
            app.PlaybackSwitch.Layout.Row = 2;
            app.PlaybackSwitch.Layout.Column = 9;

            % Create AddSoundtoLibraryButton
            app.AddSoundtoLibraryButton = uibutton(app.GridLayout6, 'push');
            app.AddSoundtoLibraryButton.ButtonPushedFcn = createCallbackFcn(app, @AddSoundtoLibraryButtonPushed, true);
            app.AddSoundtoLibraryButton.FontName = 'Comic Sans MS';
            app.AddSoundtoLibraryButton.Layout.Row = 2;
            app.AddSoundtoLibraryButton.Layout.Column = 8;
            app.AddSoundtoLibraryButton.Text = 'Add Sound to Library';

            % Create AddSoundDropDownLabel
            app.AddSoundDropDownLabel = uilabel(app.GridLayout6);
            app.AddSoundDropDownLabel.HorizontalAlignment = 'center';
            app.AddSoundDropDownLabel.FontName = 'Comic Sans MS';
            app.AddSoundDropDownLabel.FontSize = 14;
            app.AddSoundDropDownLabel.Layout.Row = 1;
            app.AddSoundDropDownLabel.Layout.Column = 1;
            app.AddSoundDropDownLabel.Text = 'Add Sound:';

            % Create AddSoundDropDown
            app.AddSoundDropDown = uidropdown(app.GridLayout6);
            app.AddSoundDropDown.FontName = 'Comic Sans MS';
            app.AddSoundDropDown.Layout.Row = 2;
            app.AddSoundDropDown.Layout.Column = 1;

            % Create TrackDropDown
            app.TrackDropDown = uidropdown(app.GridLayout6);
            app.TrackDropDown.Items = {'Track 1', 'Track 2', 'Track 3', 'Track 4'};
            app.TrackDropDown.FontName = 'Comic Sans MS';
            app.TrackDropDown.Layout.Row = 2;
            app.TrackDropDown.Layout.Column = 2;
            app.TrackDropDown.Value = 'Track 1';

            % Create AddSoundDropDownLabel_2
            app.AddSoundDropDownLabel_2 = uilabel(app.GridLayout6);
            app.AddSoundDropDownLabel_2.HorizontalAlignment = 'center';
            app.AddSoundDropDownLabel_2.FontName = 'Comic Sans MS';
            app.AddSoundDropDownLabel_2.FontSize = 14;
            app.AddSoundDropDownLabel_2.Layout.Row = 1;
            app.AddSoundDropDownLabel_2.Layout.Column = 2;
            app.AddSoundDropDownLabel_2.Text = 'To Track:';

            % Create AddSoundStartTimeEditField
            app.AddSoundStartTimeEditField = uieditfield(app.GridLayout6, 'numeric');
            app.AddSoundStartTimeEditField.FontName = 'Comic Sans MS';
            app.AddSoundStartTimeEditField.Layout.Row = 2;
            app.AddSoundStartTimeEditField.Layout.Column = 3;

            % Create AddSoundDropDownLabel_3
            app.AddSoundDropDownLabel_3 = uilabel(app.GridLayout6);
            app.AddSoundDropDownLabel_3.HorizontalAlignment = 'center';
            app.AddSoundDropDownLabel_3.FontName = 'Comic Sans MS';
            app.AddSoundDropDownLabel_3.FontSize = 14;
            app.AddSoundDropDownLabel_3.Layout.Row = 1;
            app.AddSoundDropDownLabel_3.Layout.Column = 3;
            app.AddSoundDropDownLabel_3.Text = 'At Time (s)';

            % Create RepeatSwitch
            app.RepeatSwitch = uiswitch(app.GridLayout6, 'slider');
            app.RepeatSwitch.FontName = 'Comic Sans MS';
            app.RepeatSwitch.Layout.Row = 2;
            app.RepeatSwitch.Layout.Column = 4;

            % Create AddSoundDropDownLabel_4
            app.AddSoundDropDownLabel_4 = uilabel(app.GridLayout6);
            app.AddSoundDropDownLabel_4.HorizontalAlignment = 'center';
            app.AddSoundDropDownLabel_4.FontName = 'Comic Sans MS';
            app.AddSoundDropDownLabel_4.FontSize = 14;
            app.AddSoundDropDownLabel_4.Layout.Row = 1;
            app.AddSoundDropDownLabel_4.Layout.Column = 4;
            app.AddSoundDropDownLabel_4.Text = 'Repeat';

            % Create AddSoundDropDownLabel_5
            app.AddSoundDropDownLabel_5 = uilabel(app.GridLayout6);
            app.AddSoundDropDownLabel_5.HorizontalAlignment = 'center';
            app.AddSoundDropDownLabel_5.FontName = 'Comic Sans MS';
            app.AddSoundDropDownLabel_5.FontSize = 14;
            app.AddSoundDropDownLabel_5.Layout.Row = 1;
            app.AddSoundDropDownLabel_5.Layout.Column = 5;
            app.AddSoundDropDownLabel_5.Text = 'Repeat Every (ms)';

            % Create RepeatEvery
            app.RepeatEvery = uieditfield(app.GridLayout6, 'numeric');
            app.RepeatEvery.FontName = 'Comic Sans MS';
            app.RepeatEvery.Layout.Row = 2;
            app.RepeatEvery.Layout.Column = 5;

            % Create RepeatQuantity
            app.RepeatQuantity = uieditfield(app.GridLayout6, 'numeric');
            app.RepeatQuantity.FontName = 'Comic Sans MS';
            app.RepeatQuantity.Layout.Row = 2;
            app.RepeatQuantity.Layout.Column = 6;

            % Create AddSoundDropDownLabel_6
            app.AddSoundDropDownLabel_6 = uilabel(app.GridLayout6);
            app.AddSoundDropDownLabel_6.HorizontalAlignment = 'center';
            app.AddSoundDropDownLabel_6.FontName = 'Comic Sans MS';
            app.AddSoundDropDownLabel_6.FontSize = 14;
            app.AddSoundDropDownLabel_6.Layout.Row = 1;
            app.AddSoundDropDownLabel_6.Layout.Column = 6;
            app.AddSoundDropDownLabel_6.Text = 'Repeat n Times';

            % Create AddSoundButton
            app.AddSoundButton = uibutton(app.GridLayout6, 'push');
            app.AddSoundButton.ButtonPushedFcn = createCallbackFcn(app, @AddSoundButtonPushed, true);
            app.AddSoundButton.FontName = 'Comic Sans MS';
            app.AddSoundButton.FontSize = 18;
            app.AddSoundButton.Layout.Row = [1 2];
            app.AddSoundButton.Layout.Column = 7;
            app.AddSoundButton.Text = 'Add Sound';

            % Create TimeLabel
            app.TimeLabel = uilabel(app.GridLayout6);
            app.TimeLabel.HorizontalAlignment = 'center';
            app.TimeLabel.FontName = 'Comic Sans MS';
            app.TimeLabel.FontSize = 24;
            app.TimeLabel.FontColor = [0.6353 0.0784 0.1843];
            app.TimeLabel.Layout.Row = 1;
            app.TimeLabel.Layout.Column = 9;
            app.TimeLabel.Text = '00:00.000';

            % Create astl_Sound_Name
            app.astl_Sound_Name = uieditfield(app.GridLayout6, 'text');
            app.astl_Sound_Name.FontName = 'Comic Sans MS';
            app.astl_Sound_Name.Layout.Row = 1;
            app.astl_Sound_Name.Layout.Column = 8;

            % Create MasterPanel
            app.MasterPanel = uipanel(app.GridLayout);
            app.MasterPanel.TitlePosition = 'centertop';
            app.MasterPanel.Title = 'Master';
            app.MasterPanel.Layout.Row = [3 6];
            app.MasterPanel.Layout.Column = 5;
            app.MasterPanel.FontName = 'Comic Sans MS';
            app.MasterPanel.FontSize = 18;

            % Create GridLayout2_5
            app.GridLayout2_5 = uigridlayout(app.MasterPanel);
            app.GridLayout2_5.ColumnWidth = {'1x', '1x', '1x', '1x'};
            app.GridLayout2_5.RowHeight = {'1x', '1x', '1x', '1x', '1x'};

            % Create MasterLeftMeter
            app.MasterLeftMeter = uiaudiometer(app.GridLayout2_5);
            app.MasterLeftMeter.Layout.Row = [1 4];
            app.MasterLeftMeter.Layout.Column = [1 2];

            % Create MasterRightMeter
            app.MasterRightMeter = uiaudiometer(app.GridLayout2_5);
            app.MasterRightMeter.Layout.Row = [1 4];
            app.MasterRightMeter.Layout.Column = [3 4];

            % Create MasterGainSlider
            app.MasterGainSlider = uislider(app.GridLayout2_5);
            app.MasterGainSlider.Limits = [-12 12];
            app.MasterGainSlider.MajorTicks = [-12 -9 -6 -3 0 3 6 9 12];
            app.MasterGainSlider.MajorTickLabels = {'-12', '-9', '-6', '-3', '0', '+3', '+6', '+9', '12'};
            app.MasterGainSlider.FontName = 'Comic Sans MS';
            app.MasterGainSlider.Layout.Row = 5;
            app.MasterGainSlider.Layout.Column = [1 4];

            % Create Track2Panel
            app.Track2Panel = uipanel(app.GridLayout);
            app.Track2Panel.TitlePosition = 'centertop';
            app.Track2Panel.Title = 'Track 2';
            app.Track2Panel.Layout.Row = [3 6];
            app.Track2Panel.Layout.Column = 2;
            app.Track2Panel.FontName = 'Comic Sans MS';
            app.Track2Panel.FontSize = 18;

            % Create GridLayout2_6
            app.GridLayout2_6 = uigridlayout(app.Track2Panel);
            app.GridLayout2_6.ColumnWidth = {'1x', '1x', '1x', '1x'};
            app.GridLayout2_6.RowHeight = {'1x', '1x', '1x', '1x', '1x'};

            % Create Track2ParseButton
            app.Track2ParseButton = uibutton(app.GridLayout2_6, 'push');
            app.Track2ParseButton.ButtonPushedFcn = createCallbackFcn(app, @Track2ParseButtonPushed, true);
            app.Track2ParseButton.FontName = 'Comic Sans MS';
            app.Track2ParseButton.Layout.Row = 1;
            app.Track2ParseButton.Layout.Column = [3 4];
            app.Track2ParseButton.Text = 'Parse';

            % Create Track2PanKnob
            app.Track2PanKnob = uiknob(app.GridLayout2_6, 'continuous');
            app.Track2PanKnob.Limits = [-1 1];
            app.Track2PanKnob.ValueChangedFcn = createCallbackFcn(app, @Track2PanKnobValueChanged, true);
            app.Track2PanKnob.Layout.Row = [3 4];
            app.Track2PanKnob.Layout.Column = [2 3];
            app.Track2PanKnob.FontName = 'Comic Sans MS';

            % Create Track2GainSlider
            app.Track2GainSlider = uislider(app.GridLayout2_6);
            app.Track2GainSlider.Limits = [-12 12];
            app.Track2GainSlider.MajorTicks = [-12 -9 -6 -3 0 3 6 9 12];
            app.Track2GainSlider.MajorTickLabels = {'-12', '-9', '-6', '-3', '0', '+3', '+6', '+9', '12'};
            app.Track2GainSlider.ValueChangedFcn = createCallbackFcn(app, @Track2GainSliderValueChanged, true);
            app.Track2GainSlider.FontName = 'Comic Sans MS';
            app.Track2GainSlider.Layout.Row = 5;
            app.Track2GainSlider.Layout.Column = [1 4];

            % Create Track2ClearButton
            app.Track2ClearButton = uibutton(app.GridLayout2_6, 'push');
            app.Track2ClearButton.ButtonPushedFcn = createCallbackFcn(app, @Track2ClearButtonPushed, true);
            app.Track2ClearButton.FontName = 'Comic Sans MS';
            app.Track2ClearButton.Layout.Row = 1;
            app.Track2ClearButton.Layout.Column = [1 2];
            app.Track2ClearButton.Text = 'Clear';

            % Create TrackEnabledSwitch_2Label
            app.TrackEnabledSwitch_2Label = uilabel(app.GridLayout2_6);
            app.TrackEnabledSwitch_2Label.HorizontalAlignment = 'center';
            app.TrackEnabledSwitch_2Label.FontName = 'Comic Sans MS';
            app.TrackEnabledSwitch_2Label.Layout.Row = 2;
            app.TrackEnabledSwitch_2Label.Layout.Column = [1 2];
            app.TrackEnabledSwitch_2Label.Text = 'Track Enabled';

            % Create Track2EnabledSwitch
            app.Track2EnabledSwitch = uiswitch(app.GridLayout2_6, 'slider');
            app.Track2EnabledSwitch.ValueChangedFcn = createCallbackFcn(app, @Track2EnabledSwitchValueChanged, true);
            app.Track2EnabledSwitch.FontName = 'Comic Sans MS';
            app.Track2EnabledSwitch.Layout.Row = 2;
            app.Track2EnabledSwitch.Layout.Column = [3 4];
            app.Track2EnabledSwitch.Value = 'On';

            % Create Track3Panel
            app.Track3Panel = uipanel(app.GridLayout);
            app.Track3Panel.TitlePosition = 'centertop';
            app.Track3Panel.Title = 'Track 3';
            app.Track3Panel.Layout.Row = [3 6];
            app.Track3Panel.Layout.Column = 3;
            app.Track3Panel.FontName = 'Comic Sans MS';
            app.Track3Panel.FontSize = 18;

            % Create GridLayout2_7
            app.GridLayout2_7 = uigridlayout(app.Track3Panel);
            app.GridLayout2_7.ColumnWidth = {'1x', '1x', '1x', '1x'};
            app.GridLayout2_7.RowHeight = {'1x', '1x', '1x', '1x', '1x'};

            % Create Track3ParseButton
            app.Track3ParseButton = uibutton(app.GridLayout2_7, 'push');
            app.Track3ParseButton.ButtonPushedFcn = createCallbackFcn(app, @Track3ParseButtonPushed, true);
            app.Track3ParseButton.FontName = 'Comic Sans MS';
            app.Track3ParseButton.Layout.Row = 1;
            app.Track3ParseButton.Layout.Column = [3 4];
            app.Track3ParseButton.Text = 'Parse';

            % Create Track3PanKnob
            app.Track3PanKnob = uiknob(app.GridLayout2_7, 'continuous');
            app.Track3PanKnob.Limits = [-1 1];
            app.Track3PanKnob.ValueChangedFcn = createCallbackFcn(app, @Track3PanKnobValueChanged, true);
            app.Track3PanKnob.Layout.Row = [3 4];
            app.Track3PanKnob.Layout.Column = [2 3];
            app.Track3PanKnob.FontName = 'Comic Sans MS';

            % Create Track3GainSlider
            app.Track3GainSlider = uislider(app.GridLayout2_7);
            app.Track3GainSlider.Limits = [-12 12];
            app.Track3GainSlider.MajorTicks = [-12 -9 -6 -3 0 3 6 9 12];
            app.Track3GainSlider.MajorTickLabels = {'-12', '-9', '-6', '-3', '0', '+3', '+6', '+9', '12'};
            app.Track3GainSlider.ValueChangedFcn = createCallbackFcn(app, @Track3GainSliderValueChanged, true);
            app.Track3GainSlider.FontName = 'Comic Sans MS';
            app.Track3GainSlider.Layout.Row = 5;
            app.Track3GainSlider.Layout.Column = [1 4];

            % Create Track3ClearButton
            app.Track3ClearButton = uibutton(app.GridLayout2_7, 'push');
            app.Track3ClearButton.ButtonPushedFcn = createCallbackFcn(app, @Track3ClearButtonPushed, true);
            app.Track3ClearButton.FontName = 'Comic Sans MS';
            app.Track3ClearButton.Layout.Row = 1;
            app.Track3ClearButton.Layout.Column = [1 2];
            app.Track3ClearButton.Text = 'Clear';

            % Create TrackEnabledSwitch_2Label_2
            app.TrackEnabledSwitch_2Label_2 = uilabel(app.GridLayout2_7);
            app.TrackEnabledSwitch_2Label_2.HorizontalAlignment = 'center';
            app.TrackEnabledSwitch_2Label_2.FontName = 'Comic Sans MS';
            app.TrackEnabledSwitch_2Label_2.Layout.Row = 2;
            app.TrackEnabledSwitch_2Label_2.Layout.Column = [1 2];
            app.TrackEnabledSwitch_2Label_2.Text = 'Track Enabled';

            % Create Track3EnabledSwitch
            app.Track3EnabledSwitch = uiswitch(app.GridLayout2_7, 'slider');
            app.Track3EnabledSwitch.ValueChangedFcn = createCallbackFcn(app, @Track3EnabledSwitchValueChanged, true);
            app.Track3EnabledSwitch.FontName = 'Comic Sans MS';
            app.Track3EnabledSwitch.Layout.Row = 2;
            app.Track3EnabledSwitch.Layout.Column = [3 4];
            app.Track3EnabledSwitch.Value = 'On';

            % Create Track4Panel
            app.Track4Panel = uipanel(app.GridLayout);
            app.Track4Panel.TitlePosition = 'centertop';
            app.Track4Panel.Title = 'Track 4';
            app.Track4Panel.Layout.Row = [3 6];
            app.Track4Panel.Layout.Column = 4;
            app.Track4Panel.FontName = 'Comic Sans MS';
            app.Track4Panel.FontSize = 18;

            % Create GridLayout2_8
            app.GridLayout2_8 = uigridlayout(app.Track4Panel);
            app.GridLayout2_8.ColumnWidth = {'1x', '1x', '1x', '1x'};
            app.GridLayout2_8.RowHeight = {'1x', '1x', '1x', '1x', '1x'};

            % Create Track4ParseButton
            app.Track4ParseButton = uibutton(app.GridLayout2_8, 'push');
            app.Track4ParseButton.ButtonPushedFcn = createCallbackFcn(app, @Track4ParseButtonPushed, true);
            app.Track4ParseButton.FontName = 'Comic Sans MS';
            app.Track4ParseButton.Layout.Row = 1;
            app.Track4ParseButton.Layout.Column = [3 4];
            app.Track4ParseButton.Text = 'Parse';

            % Create Track4PanKnob
            app.Track4PanKnob = uiknob(app.GridLayout2_8, 'continuous');
            app.Track4PanKnob.Limits = [-1 1];
            app.Track4PanKnob.ValueChangedFcn = createCallbackFcn(app, @Track4PanKnobValueChanged, true);
            app.Track4PanKnob.Layout.Row = [3 4];
            app.Track4PanKnob.Layout.Column = [2 3];
            app.Track4PanKnob.FontName = 'Comic Sans MS';

            % Create Track4GainSlider
            app.Track4GainSlider = uislider(app.GridLayout2_8);
            app.Track4GainSlider.Limits = [-12 12];
            app.Track4GainSlider.MajorTicks = [-12 -9 -6 -3 0 3 6 9 12];
            app.Track4GainSlider.MajorTickLabels = {'-12', '-9', '-6', '-3', '0', '+3', '+6', '+9', '12'};
            app.Track4GainSlider.FontName = 'Comic Sans MS';
            app.Track4GainSlider.Layout.Row = 5;
            app.Track4GainSlider.Layout.Column = [1 4];

            % Create Track4ClearButton
            app.Track4ClearButton = uibutton(app.GridLayout2_8, 'push');
            app.Track4ClearButton.ButtonPushedFcn = createCallbackFcn(app, @Track4ClearButtonPushed, true);
            app.Track4ClearButton.FontName = 'Comic Sans MS';
            app.Track4ClearButton.Layout.Row = 1;
            app.Track4ClearButton.Layout.Column = [1 2];
            app.Track4ClearButton.Text = 'Clear';

            % Create TrackEnabledSwitch_2Label_3
            app.TrackEnabledSwitch_2Label_3 = uilabel(app.GridLayout2_8);
            app.TrackEnabledSwitch_2Label_3.HorizontalAlignment = 'center';
            app.TrackEnabledSwitch_2Label_3.FontName = 'Comic Sans MS';
            app.TrackEnabledSwitch_2Label_3.Layout.Row = 2;
            app.TrackEnabledSwitch_2Label_3.Layout.Column = [1 2];
            app.TrackEnabledSwitch_2Label_3.Text = 'Track Enabled';

            % Create Track4EnabledSwitch
            app.Track4EnabledSwitch = uiswitch(app.GridLayout2_8, 'slider');
            app.Track4EnabledSwitch.ValueChangedFcn = createCallbackFcn(app, @Track4EnabledSwitchValueChanged, true);
            app.Track4EnabledSwitch.FontName = 'Comic Sans MS';
            app.Track4EnabledSwitch.Layout.Row = 2;
            app.Track4EnabledSwitch.Layout.Column = [3 4];
            app.Track4EnabledSwitch.Value = 'On';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    %% App creation and deletion
    methods (Access = public)

        % Construct app
        function app = ATCInteractiveAppDemo_exported

            runningApp = getRunningApp(app);

            % Check for running singleton app
            if isempty(runningApp)

                % Create UIFigure and components
                createComponents(app)

                % Register the app with App Designer
                registerApp(app, app.UIFigure)

                % Execute the startup function
                runStartupFcn(app, @startupFcn)
            else

                % Focus the running singleton app
                figure(runningApp.UIFigure)

                app = runningApp;
            end

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end
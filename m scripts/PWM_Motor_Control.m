%% Create a new Simulink model for PWM Motor Control
model = 'PWM_Motor_Control';
if bdIsLoaded(model); close_system(model,0); 
  end
new_system(model);
open_system(model);

%% Parameters
PWM_freq = 5000;       % 5 kHz PWM frequency
K = 1;                 % Motor gain
tau = 0.5;             % Motor time constant
StopTime = '2';        % Simulation time in seconds

%% Add blocks
% Reference Speed Input
add_block('simulink/Sources/Constant', [model '/ReferenceSpeed'], ...
    'Value','1','Position',[50 50 100 80]);

% Sum block for error calculation
add_block('simulink/Math Operations/Sum', [model '/Sum'], ...
    'Inputs','+-','Position',[150 50 180 80]);

% P Gain
add_block('simulink/Math Operations/Gain', [model '/P_Gain'], ...
    'Gain','1','Position',[220 50 250 80]);

% PWM Generator: Compare input with sawtooth to create duty cycle
add_block('simulink/Sources/Repeating Sequence', [model '/Sawtooth'], ...
    'rep_seq_t','[0 1]','rep_seq_y','[0 1]', ...
    'Position',[50 150 100 180]);

add_block('simulink/Logic and Bit Operations/Relational Operator', [model '/PWM_Compare'], ...
    'Operator','>','Position',[150 150 180 180]);

% Motor Transfer Function: G(s) = K / (tau*s+1)
num = [K]; 
den = [tau 1];
add_block('simulink/Continuous/Transfer Fcn', [model '/Motor'], ...
    'Numerator', mat2str(num), ...
    'Denominator', mat2str(den), ...
    'Position',[300 50 350 80]);

% Scopes
add_block('simulink/Sinks/Scope', [model '/SpeedScope'], ...
    'Position',[400 50 450 80]);
add_block('simulink/Sinks/Scope', [model '/PWMScope'], ...
    'Position',[250 150 300 180]);

%% Connect Blocks
add_line(model,'ReferenceSpeed/1','Sum/1');
add_line(model,'Motor/1','Sum/2');
add_line(model,'Sum/1','P_Gain/1');
add_line(model,'P_Gain/1','PWM_Compare/1');
add_line(model,'Sawtooth/1','PWM_Compare/2');
add_line(model,'PWM_Compare/1','Motor/1');
add_line(model,'Motor/1','SpeedScope/1');
add_line(model,'PWM_Compare/1','PWMScope/1');

%% Set simulation parameters
set_param(model,'StopTime',StopTime);
save_system(model);

disp('PWM Motor Control model created successfully. Open Simulink to run it.');

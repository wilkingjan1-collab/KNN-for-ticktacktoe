% GENERATE_DATA Erzeuge einen Datensatz von TicTacToe-Stellungen und empfohlenen Zügen
% Dieses Skript erzeugt einen Datensatz entsprechend dem Cleve Moler TicTacToe-Kapitel:
% - listet alle möglichen 3x3-Bretter auf
% - filtert legale Stellungen (Zuganzahl und keine unmöglichen Doppel-Siege)
% - für jede nicht-terminale Stellung bestimmt den Spieler am Zug und den
%   empfohlenen Zug mit der naiven `strategy` aus dem Kapitel
% - speichert den Datensatz in `data_tictactoe.mat` im Arbeitsverzeichnis

% Kompatibel mit MATLAB und Octave.

clearvars; clc;

% Logging / Laufzeit-Optionen
verbose = true;                            % true = Ausgabe in Konsole und Logdatei
logfile = fullfile(pwd,'generate_data.log');
fid = fopen(logfile,'w');                  % Logdatei (überschreibt)
fprintf(fid,'generate_data log started: %s\n', datestr(now));
progress_step = 5000;                      % wie oft Fortschritt ausgegeben wird
tic;                                       % Startzeit messen

% Zähler für Logging
cnt_total = 0;
cnt_legal = 0;
cnt_terminal = 0;
cnt_moves_found = 0;
cnt_win_green = 0;
cnt_win_blue = 0;

if verbose
    fprintf('Logging to %s\n', logfile);
end

% Alle möglichen Bretter auflisten (3^9 Möglichkeiten)
vals = [-1 0 1]; % -1 = blau, 0 = leer, +1 = grün
N = 3^9;
boards = zeros(N,9);
for idx = 0:(N-1)
    x = idx;
    v = zeros(1,9);
    for k = 1:9
        r = mod(x,3) + 1; % 1..3 Index in `vals`
        v(k) = vals(r);
        x = floor(x/3);
    end
    boards(idx+1,:) = v;
end

is_legal = false(N,1);
winner_label = zeros(N,1);
player_to_move = zeros(N,1);
move_idx = zeros(N,1); % 1..9 Index des empfohlenen Zugs (0 = keiner)

for t = 1:N
    cnt_total = cnt_total + 1;
    X = reshape(boards(t,:),3,3)'; % in 3x3 umwandeln (Zeilen-major wie in Cleve Moler)

    % Zähle Steine
    n1 = sum(X(:) == 1);
    n_1 = sum(X(:) == -1);

    % Legalität: Differenz der Zuganzahl 0 oder 1 (grün beginnt)
    if ~( (n1 == n_1) || (n1 == n_1 + 1) )
        continue
    end

    % Gewinner ermitteln nach Magic15 (0 = keiner, 1 = grün, -1 = blau, 2 = Unentschieden)
    p = winner_magic(X);
    winner_label(t) = p;
    % Statistik: Gewinner zählen (Magic15)
    if p == 1
        cnt_win_green = cnt_win_green + 1;
    elseif p == -1
        cnt_win_blue = cnt_win_blue + 1;
    end

    % Unmögliche Stellungen ausschließen, in denen beide nach Magic15 gewonnen haben
    has1 = has_magic_win(X,1);
    has_1 = has_magic_win(X,-1);
    if has1 && has_1
        continue
    end

    % Falls bereits jemand gewonnen hat: Stellung ist legal, aber kein Zug erwartet
    is_legal(t) = true;
    cnt_legal = cnt_legal + 1;

    % Spieler am Zug bestimmen: gleiche Anzahl -> grün(+1), sonst blau(-1)
    if n1 == n_1
        p_move = 1;
    else
        p_move = -1;
    end
    player_to_move(t) = p_move;

    % Wenn Stellung terminal ist (Gewinner oder volles Feld), Zug überspringen
    if p ~= 0 || all(X(:) ~= 0)
        move_idx(t) = 0;
        cnt_terminal = cnt_terminal + 1;
        continue
    end

    % Empfohlenen Zug berechnen mit der Cleve Moler Strategie
    [i,j] = strategy(X,p_move);
    if isempty(i)
        move_idx(t) = 0;
    else
        move_idx(t) = sub2ind([3,3], i, j);
        cnt_moves_found = cnt_moves_found + 1;
    end

    % periodisches Logging
    if verbose && mod(cnt_total,progress_step) == 0
        elapsed = toc;
        msg = sprintf('Processed %d/%d boards (legal: %d, terminal: %d, moves_found: %d) elapsed: %.1fs', cnt_total, N, cnt_legal, cnt_terminal, cnt_moves_found, elapsed);
        fprintf('%s\n', msg);
        fprintf(fid, '%s\n', msg);
    end
end

% Nur legale Positionen behalten
valid = find(is_legal);
boards = boards(valid,:);
winner_label = winner_label(valid);
player_to_move = player_to_move(valid);
move_idx = move_idx(valid);

% Datensatz speichern
outfile = fullfile(pwd,'data_tictactoe.mat');
save(outfile,'boards','winner_label','player_to_move','move_idx');

fprintf('Gespeichert %d legale Stellungen in %s\n', size(boards,1), outfile);

% Abschließendes Logging / Zusammenfassung
elapsed = toc;
summary = sprintf('\nSummary:\n  processed boards: %d\n  legal: %d\n  terminal: %d\n  moves found: %d\n  wins (green): %d\n  wins (blue): %d\n  elapsed (s): %.2f\n', cnt_total, cnt_legal, cnt_terminal, cnt_moves_found, cnt_win_green, cnt_win_blue, elapsed);
fprintf('%s\n', summary);
fprintf(fid, '%s\n', summary);

% Save log struct
log.cnt_total = cnt_total;
log.cnt_legal = cnt_legal;
log.cnt_terminal = cnt_terminal;
log.cnt_moves_found = cnt_moves_found;
log.cnt_win_green = cnt_win_green;
log.cnt_win_blue = cnt_win_blue;
log.elapsed = elapsed;
save(fullfile(pwd,'data_tictactoe_log.mat'),'log');

fclose(fid);

%% --- Hilfsfunktionen ---
function p = winner(X)
% p = winner(X) gibt zurück:
% p = 0, kein Gewinner
% p = -1, blau hat gewonnen
% p = 1, grün hat gewonnen
% p = 2, Unentschieden (volles Feld)

for pp = [-1 1]
    s = 3*pp;
    win = any(sum(X) == s) || any(sum(X') == s) || ...
          sum(diag(X)) == s || sum(diag(fliplr(X))) == s;
    if win
        p = pp;
        return
    end
end
if all(X(:) ~= 0)
    p = 2;
else
    p = 0;
end
end

function [i,j] = strategy(X,p)
% [i,j] = strategy(X,p) aus dem Cleve Moler Kapitel (naiv)
pause(0);

[i,j] = winningmove_magic(X,p);
if isempty(i)
    [i,j] = winningmove_magic(X,-p);
end
if isempty(i)
    [I,J] = find(X == 0);
    if isempty(I)
        i = [];
        j = [];
        return
    end
    m = ceil(rand*length(I));
    i = I(m);
    j = J(m);
end
end

function [i,j] = winningmove(X,p)
% Finde einen möglichen Gewinnzug für Spieler p.
s = 2*p;
i = [];
j = [];
if any(sum(X) == s)
    j0 = find(sum(X) == s);
    % erste passende Spalte mit einer freien Zelle wählen
    for jj = j0(:)'
        ii = find(X(:,jj) == 0);
        if ~isempty(ii)
            i = ii(1);
            j = jj;
            return
        end
    end
elseif any(sum(X') == s)
    i0 = find(sum(X') == s);
    for ii = i0(:)'
        jj = find(X(ii,:) == 0);
        if ~isempty(jj)
            i = ii;
            j = jj(1);
            return
        end
    end
elseif sum(diag(X)) == s
    ii = find(diag(X) == 0);
    if ~isempty(ii)
        i = ii(1);
        j = i;
        return
    end
elseif sum(diag(fliplr(X))) == s
    d = diag(fliplr(X));
    ii = find(d == 0);
    if ~isempty(ii)
        i = ii(1);
        j = 4 - i;
        return
    end
else
    i = [];
    j = [];
end
end

function tf = has_magic_win(X,p)
% Prüft, ob Spieler p eine Triplett von besetzten Zellen hat, deren
% zugeordnete Lo-Shu-Zahlen auf 15 summieren.
M = [8 1 6; 3 5 7; 4 9 2];
nums = M(X == p);
tf = false;
if numel(nums) < 3
    return
end
combos = nchoosek(nums,3);
if any(sum(combos,2) == 15)
    tf = true;
end
end

function p = winner_magic(X)
% winner_magic prüft Gewinn nach Magic15/Lo-Shu
for pp = [1, -1]
    if has_magic_win(X,pp)
        p = pp;
        return
    end
end
if all(X(:) ~= 0)
    p = 2;
else
    p = 0;
end
end

function [i,j] = winningmove_magic(X,p)
% winningmove_magic sucht einen Zug (i,j), der Spieler p sofort gewinnen lässt
M = [8 1 6; 3 5 7; 4 9 2];
nums = M(X == p);
i = [];
j = [];
empties = find(X == 0);
for k = 1:numel(empties)
    lin = empties(k);
    [r,c] = ind2sub([3,3], lin);
    cand = [nums; M(r,c)];
    if numel(cand) >= 3
        combos = nchoosek(cand,3);
        if any(sum(combos,2) == 15)
            i = r; j = c; return
        end
    end
end
end

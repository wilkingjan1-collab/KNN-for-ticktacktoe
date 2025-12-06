% GENERATE_DATA Erzeuge einen Datensatz von TicTacToe-Stellungen und empfohlenen Zügen
% Dieses Skript erzeugt einen Datensatz entsprechend dem Cleve Moler TicTacToe-Kapitel:
% - listet alle möglichen 3x3-Bretter auf
% - filtert legale Stellungen (Zuganzahl und keine unmöglichen Doppel-Siege)
% - für jede nicht-terminale Stellung bestimmt den Spieler am Zug und den
%   empfohlenen Zug mit der naiven `strategy` aus dem Kapitel
% - speichert den Datensatz in `data_tictactoe.mat` im Arbeitsverzeichnis

% Kompatibel mit MATLAB und Octave.

clearvars; clc;

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
    X = reshape(boards(t,:),3,3)'; % in 3x3 umwandeln (Zeilen-major wie in Cleve Moler)

    % Zähle Steine
    n1 = sum(X(:) == 1);
    n_1 = sum(X(:) == -1);

    % Legalität: Differenz der Zuganzahl 0 oder 1 (grün beginnt)
    if ~( (n1 == n_1) || (n1 == n_1 + 1) )
        continue
    end

    % Gewinner ermitteln (0 = keiner, 1 = grün, -1 = blau, 2 = Unentschieden)
    p = winner(X);
    winner_label(t) = p;

    % Unmögliche Stellungen ausschließen, in denen beide gewonnen haben
    % (die winner()-Funktion gibt ggf. nur den ersten Treffer zurück)
    has1 = any(sum(X == 1) == 3) || any(sum(X' == 1) == 3) || sum(diag(X) == 1) == 3 || sum(diag(fliplr(X)) == 1) == 3;
    has_1 = any(sum(X == -1) == 3) || any(sum(X' == -1) == 3) || sum(diag(X) == -1) == 3 || sum(diag(fliplr(X)) == -1) == 3;
    if has1 && has_1
        continue
    end

    % Falls bereits jemand gewonnen hat: Stellung ist legal, aber kein Zug erwartet
    is_legal(t) = true;

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
        continue
    end

    % Empfohlenen Zug berechnen mit der Cleve Moler Strategie
    [i,j] = strategy(X,p_move);
    if isempty(i)
        move_idx(t) = 0;
    else
        move_idx(t) = sub2ind([3,3], i, j);
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

[i,j] = winningmove(X,p);
if isempty(i)
    [i,j] = winningmove(X,-p);
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

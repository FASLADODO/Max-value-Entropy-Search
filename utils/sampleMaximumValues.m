% Author: Zi Wang
% This function is adapted from the code for the paper
% Hernández-Lobato J. M., Hoffman M. W. and Ghahramani Z.
% Predictive Entropy Search for Efficient Global Optimization of Black-box
% Functions, In NIPS, 2014.
% https://bitbucket.org/jmh233/codepesnips2014
function [ samples] = sampleMaximumValues(nM, nK, xx, ...
                 yy, sigma0, sigma, l, xmin, xmax, nFeatures, epsilon)
% This function returns sampled maximum values for the posterior GP 
% conditioned on current obervations. We construct random features and 
% optimize functions drawn from the posterior GP.
% nM is the number of sampled GP hyper-parameter settings.
% nK is the number of sampled maximum values.
% xx, yy are the current observations.
% sigma0, sigma, l are the hyper-parameters of the Gaussian kernel.
% xmin, xmax are the lower and upper bounds for the search space.
% nFeatures is the number of random features sampled to approximate the
% GP.
% epsilon is an offset on the sampled max-value.
if nargin <= 10; epsilon = 0.1; end
d = size(xx, 2);

samples = zeros(nM, nK)*-1e10;

for i = 1 : nM
    for j = 1:nK
        
        % Draw weights for the random features.
        
        W = randn(nFeatures, d) .* repmat(sqrt(l(i,:)), nFeatures, 1);
        b = 2 * pi * rand(nFeatures, 1);
        
        % Compute the features for xx.
        Z = sqrt(2 * sigma(i) / nFeatures) * cos(W * xx' + ...
            repmat(b, 1, size(xx, 1)));
       
        % Draw the coefficient a.
        noise = randn(nFeatures, 1);
        if (size(xx, 1) < nFeatures)
            % We adopt the formula $a \sim \N(Z(Z'Z + \sigma^2 I)^{-1} y, 
            % I-Z(Z'Z + \sigma^2 I)Z')$.
            Sigma = Z' * Z + sigma0(i) * eye(size(xx, 1));
            mu = Z*chol2invchol(Sigma)*yy;
            [U, D] = eig(Sigma);
            D = diag(D);
            R = (sqrt(D) .* (sqrt(D) + sqrt(sigma0(i)))).^-1;
            a = noise - (Z * (U * (R .* (U' * (Z' * noise))))) + mu;
        else
            % $a \sim \N((ZZ'/\sigma^2 + I)^{-1} Z y / \sigma^2,
            % (ZZ'/\sigma^2 + I)^{-1})$.
            Sigma = chol2invchol(cross(Z, Z') / sigma0(i) + eye(nFeatures));
            mu = Sigma * Z * yy / sigma0(i);
            a = mu + noise * chol(Sigma);
            
        end
        
        % Obtain a function sampled from the posterior GP.
        
        targetVector = @(x) (a' * sqrt(2 * sigma(i) / nFeatures) * ...
            cos(W * x' + repmat(b, 1, size(x, 1))))';
        targetVectorGradient = @(x) a' * -sqrt(2 * sigma(i) / ...
            nFeatures) * (repmat(sin(W * x' + b), 1, d) .* W);
        
        target = @(x) wrap_target(targetVector, targetVectorGradient, x);
        
        [~, sample]= globalMaximization(target, xmin, xmax, xx);
        
        samples(i, j) = sample;
        
        % If the optimization failed, we manually set the
        % sample to be max(yy) + epsilon.
        if sample < max(yy) + epsilon
            samples(i, j) = max(yy) + epsilon;
        end
    end
end
end


function [f,g] = wrap_target(tf, tg, x)
f = tf(x);
if nargout > 1
    g = tg(x);
end
end
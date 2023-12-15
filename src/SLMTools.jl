module SLMTools


include("LatticeTools/LatticeTools.jl")
using .LatticeTools
export Lattice, elq, RealPhase, Generic, Phase, FieldVal, ComplexPhase, UPhase, UnwrappedPhase, S1Phase, Intensity, Amplitude, Modulus, RealAmplitude, RealAmp, ComplexAmplitude, ComplexAmp, LatticeField, LF, subfield, wrap, square, sublattice
export natlat, sft, isft, padout, naturalize, latticeDisplacement, toDim, r2, ldot
export downsample, upsample, coarsen, sublattice
export dualLattice, dualShiftLattice, ldq, dualPhase

include("other/Misc.jl")
using .Misc
export ramp, nabs, window, normalizeDistribution, safeInverse, hyperSum, centroid, clip, collapse

include("other/ImageProcessing.jl")
using .ImageProcessing
export getImagesAndFilenames, imageToFloatArray, itfa, castImage, loadDir, parseFileName, parseStringToNum, getOrientation, dualate, linearFit, savePhase, saveBeam, saveAs8BitBMP

include("other/PhaseIntensityMasks.jl")
using .PhaseIntensityMasks
export lfRampedParabola, lfGaussian, lfRing


include("other/HoganParameters.jl")
using .HoganParameters
export dxcam, dxslm, nslm, flambda, dXslm, Lslm, dL, LslmE, dLE

include("PhaseDiversity/LatticeIFTA.jl")
using .LatticeIFTA
export phasor, gs, gsIter, pdgs, pdgsIter, oneShot

include("PhaseDiversity/OTHelpers.jl")
using .OTHelpers
export getCostMatrix, pdCostMatrix, pdotBeamEstimate,  mapify, scalarPotentialN, otPhase, pdotPhase, pdotBeamEstimate

include("other/VisualizationHelpers.jl")
using .VisualizationHelpers
export look

# include("other/FileHelpers.jl")
# export savePhase, saveBeam, saveAs8BitBMP



export testing
end # module SLMTools
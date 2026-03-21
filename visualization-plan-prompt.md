i now want to work on a visualization script. I think now there are too much visualization scripts in @scripts/ and they are outdated since the change in output of the main program. Make
a plan using the plan mode, planning agent and think hard about:
- Create a new branch "dev/visualization" to perform the following changes. It should be updated everytime a phase of the plan is completed to keep track of the status of the project.
- i want to make a dynamic visualization script that uses matplotlib. You hsould have the option to select which things from the output of the program you want to plot: potential, state
functions, and wavefunctions (wavepackets). The plot should update live. You can find examples of how I did the plots in @scripts/
- It should have an option to export a PDf with the actual status of the plot
- You should have the options to modify: x,y axis ranges; x,y labels; figure title; labels of the plot. In all cases, it should accept LaTeX code (as $$)
- Since the potential and wavefunctions are not in the same scale, you should have the option to scale them. Do you think we can implement something to scale it automatically?
- It should have a button to exit out the script
- You should have the option (with a button or something) to export a static script of the actual status of the plot, i.e. generate a script that, once executed, directly generates the PDF
plot with the same basename of the static script
- For the exported PDF, i want to use the style @scripts/QuTu.mplstyle. For the live preview of the plot, it should use the matplotlib default style. You can include a button to toggle on
the @scripts/QuTu.mplstyle style. Do you think we should include these style params inside the script or keep it in a separate file?

The next thing I want to do is to generate a script to similarly visualize the dynamics of the wavefunctions and be able to export it as MP4.

Since, for both those scripts we must extract the data from the OUTPUT file, do you think we should create another script to extract the desired data from the OUTPUT? So that it can be
called from inside the visualization scripts. In this case, the user can also use this script to extract the desired data to a file


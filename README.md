# GUI for Biological Imaging: Lightsheet Microscopy and More

[ Under Construction - Please exercise caution as our team continues to refine the codebase, as there may be existing bugs yet to be addressed.]


## Introduction
Image segmentation is utilized in many areas of biological research for identifying specific image regions, extracting features, and quantifying signals in microscopy images. Furthermore, automated segmentation approaches can be utilized to reduce the size of data sets by cropping out the regions of interest (ROIs) for subsequent image processing and are especially relevant when handling large datasets, as is common in many light sheet modalities. Here we describe a modular graphical user interface (GUI) developed in MATLAB which enables the user to navigate and visualize multidimensional data, apply various preprocessing options, and perform segmentation with only 3 adjustable parameters. Preprocessed data is segmented using traditional parametric methods, which post-processing options, including active contours and manual adjustments, can further refine. The resulting datasets from the segmentation can be used to train a deep neural network to perform semantic segmentation on regions for various needs. Furthermore, image segmentation facilitates the detection of centroids for various ROIs such as those that would describe the location of nuclei in a biological sample to track development.

Work from this project was presented in a [poster](Poster/FOM2024_SegmentationSoftwareProject_WillRamos.pdf) at [Focus on Microscopy (FOM) 2024](https://www.focusonmicroscopy.org/) in Genova, Liguria, Italy as well as the [New England Society for Microscopy (NESM) Spring Symposium](https://nesmicroscopy.wildapricot.org/event-5574777) in Woods Hole, MA, USA. Our abstract for FOM2024 can be found [here](https://www.focusonmicroscopy.org/2024-program-online/?source=pp&event_id=5817&tab=pdf&a_id=7311).

To get additional information about this project and our work, please refer to this [MathWorks News and Stories article](https://www.mathworks.com/company/mathworks-stories/image-processing-and-ai-based-lightsheet-microscopy-tool-provide-data-insight.html).


## GUI Overview
A screenshot of the GUI upon launch shows a cutaway view of the software’s computed boundary for a segmented *Parhyale hawaiensis* embryo with a DAPI stain imaged on a light sheet system (sample courtesy of Dr. Carsten Wolff, Marine Biological Laboratory).

![GUI](md_images/GUI_launch.png)


### GUI Result Types
Here we show three different algorithms used within the GUI on the same *Caenorhabditis elegans* embryo with a histone marker imaged on a diSPIM system.
![GUI Result Types](md_images/GUI_ResultFormatTypes.png)

From left to right, we show the GUIs capability to overlay three different result formats:
1.	**Contour**: a closed curve that represents the boundary of an ROI
2.	**Masks**: a binary image with a value of 1 inside the ROI and 0 elsewhere
3.	**Point cloud**: a set of points representing detections or centroids of segmented ROIs


### GUI Settings
The settings tab has settings for active contours, visualization, and premature stops along the parametric processing pipeline. Mask opacity will apply to pipelines that result in **masks** that will be overlayed atop images in the GUI. The point marker and marker width properties apply to **point clouds** that will plot points atop images in the GUI. Lastly, the line width property applies to **contour** outputs.

![GUI Settings Tab](md_images/GUI_SettingsTab.png)


### GUI Results Export
The export tab allows the user to set their save location as well as how they would like to export the computed results. The settings used in the GUI to produce the results are always tracked and saved, even if images were processed sparsely by skipping slice (third dimension) or time (fourth dimension) indices: there is no need to view and process the image planes sequentially. If the user has produced masks or contours, the ROI(s) properties can be computed and saved by selecting options in the Masking Properties list. By default, masks/contours are not saved as image files, but if the user toggles mask saving, masks can be saved in `.tif` image volumes or as individual 2D planes in `.png` files.

![GUI Export Tab](md_images/GUI_ExportTab.png)


### Software Architecture
The underlying architecture and modular framework we have developed to expedite the development of image processing and analysis GUIs is shown below.

1. [`ROISegmentationGUI`](Software/ROISegmentationGUI.mlapp) is the front end of the interface that calls the rest of the classes to load, process, and save data. This file launches the GUI.
2. [`ImageServer`](Software/Framework/ImageServer.m) allows for loading and navigation of 2-4D data across a variety of [formats](#compatible-file-formats).
3. [`SegmentationEngine`](Software/Framework/SegmentationEngine.m) preprocesses data, then passes it through the configured parametric algorithm to produce segmentation/detection results.
4. [`VisualizationEngine`](Software/Framework/VisualizationEngine.m) determines how to visualize the image data, depending on whether the user wants to view the **auxiliary image** or **raw image**. It also determines how to visualize the computed results in addition to moments of inertia if requested.
5. [`ExportModule`](Software/Framework/ExportModule.m) tracks settings used by the user to perform segmentations and the computed results. This can also compute statistics for **contours** or **masks**. It can then export to a variety of file formats.

![Software Architecture](md_images/FrameworkArchitectureDiagram.png)


## Workflow
The `ImageServer` manages the loading of **raw image** 2D planes from image volumes and time series across various formats. Lazy loading is on by default but can be toggled off to enable the loading of entire 3D volumes at a given time point. This data is then passed off to the compute engine, `SegmentationEngine`, which will perform the selected preprocessing options to produce an **auxiliary image**. A list of available options which can be toggled in the GUI is shown below. Here we show a *C. elegans* embryo images on our diSPIM system. This image was preprocessed with the denoising option toggled on.
![Preprocessing Data](md_images/Preprocessing.png)

The **auxiliary image** is then passed through the parametric algorithm in the `SegmentationEngine` to produce a result in one of the three acceptable [formats](#gui-result-types). The **raw image** or **auxiliary image** can be viewed with a user-selected colormap in the GUI’s main window with the computed results in a user-selected color overlaid atop. Although three sliders correspond to three different parameters, some algorithms may have more than three functions or steps in the parametric pipeline while still only using three parameters at most. One such case is shown below in the [Pipeline Visualization Tool](#pipeline-visualization-tool).

![Pipeline Visualization](md_images/Visualization.png)

Settings used to produce the results are stored in the GUI in a data structure that also keeps track of computed results. This information can then be exported.

![Data Management](md_images/DataManagement.png)

### Tools
In addition to the main GUI’s visualization and parametric processing capabilities, several embedded tools facilitate: preprocessing with GUIs, optimization of parameter selection, and post-processing. Preprocessing tools include the Crop Tool, ROI Taper Tool, and the Color Target Transform Tool. The active contours settings allow for semi-automated refinement of mask and contour outputs while the Editing Tool enables users to perform manual adjustments to results.


#### Crop Tool
The crop tool will set a bounding box to grab planes from the original data after the user has drawn an ROI. This reduces the amount of data loaded into memory and computed by the CPU, thus expediting computation while saving results relative to the original image coordinates.

![Crop Tool GUI](md_images/CropToolUse.png)


####  ROI Taper Tool
The ROI Taper Tool allows users to define ROIs they want to emphasize more than other regions. This tool will then taper in a Tukey window fashion out from the ROI boundary to the image boundary such that the pixels inside and at the edge of the ROI boundary keep their original value and pixels at the image boundary have a value of 1. This tool assists in reducing the uneven illumination artifact present throughout light sheet datasets that involve a light sheet illuminating from one direction.

![ROI Taper Tool GUI](md_images/TaperToolUse.png)


#### Color Target Transform Tool
The Color Target Transform Tool is to be used for color images only. This tool allows the user to select a pixel within the image to set a target color. The image is then transformed such that pixels with a color (RGB values) equal to the target have a value of 1 and those furthest away from the color (orthogonal in RGB or L*a*b* space) have a value of 0.

![Color Transform Tool GUI](md_images/ColorTransformTool.png)


#### Pipeline Visualization Tool

The Pipeline Visualization Tool enables users to see sequential processing steps in the parametric algorithm pipeline. The user can stop at any given step that produces one of the three acceptable [output types](#gui-result-types). Visualization of each processing step enables optimal processing and analysis for specific use cases across light sheet microscopy and other modalities. Here, we can see how the user zoomed into the top right corner of their sample in the second and third windows to ensure nuclei were separating as much as possible as they adjusted parameter sliders.

![Pipeline Visualization Tool GUI](md_images/Pipeline_Visualization.png)

#### Active Contours
The Settings tab of the GUI allows configuration of the active contours post-processing of results. Adjusting these settings requires the user to toggle Active contours on. This can be adjusted to have a variable number of iterations, smoothing, a downsample to upsample denoising factor, and contraction bias.

![Active Contours](md_images/ActiveContoursSettings.png)

#### Editing Tool
The Editing tool allows users to edit any of the Segmentation GUI's result types. We show below how a contour detection on a *P. hawaiensis* embryo can be manually refined in the Editing Tool via the turbo paint brush method. This modality of adjustment is feasible for either **mask** or **contour** results.

![Data Editing Tool GUI - Masks](md_images/EditingToolUse_masks.png)

Alternatively, if the user would like to perform blob detections such as detections of nuclei, those **point cloud** results can also be refined. The Editing Tool will place '**X**' markers on points removed from the original set of detections and place '**+**' markers where the user has manually placed new detections.

![Data Editing Tool GUI - Points](md_images/EditingToolUse.png)


### Applications
Here, we primarily focus on light sheet microscopy data from a diSPIM system and show applications of our software to this imaging modality.

#### Butterfly Ovary

Collaborators from Dr. Nipam Patel's lab at the Marine Biological Laboratory imaged butterfly ovaries with SiR-actin stain on our diSPIM system. This stain highlighted actin to facilitate the analysis of morphological changes throughout ovary maturation. However, a region at the center of the ovary obscured features when a maximum intensity projection was made because the signal was significantly higher than that of features of interest found in other slices. This case demonstrates the challenge of "autofluorescence" as found in many biological samples imaged with light sheet microscopy. We leveraged deep learning for semantic segmentation to resolve this challenge for our collaborators.

We prepared a training dataset by manually segmenting a specific ROI from a subset of data to train a model to segment this dynamic ROI across a 4D dataset, a volumetric time series of a butterfly ovary. We trained a deep network, DeepLabV3+ with a Resnet18 backbone, on ~3% of the data spread across time and space, enabling the network to infer across these higher dimensions. This network was then used to segment the ROI with excessive SiR-actin signal that would otherwise obfuscate important features in a maximum intensity projection. An example timepoint below compares the preprocessed image volume to the image volume with the segmented ROI removed (i.e. the masked 3D ROI had pixel values set to zero).

![Butterfly Ovary](md_images/Comparison_T15_sb.gif)


## Getting Started
Download the `Software` folder in this repository if you have MATLAB. Alternatively, one can download the `CompiledSoftware` folder after installing the [MATLAB runtime]( https://www.mathworks.com/products/compiler/matlab-runtime.html). This enables users without a MATLAB license to run our software. This software was developed in MATLAB 2023b and we **cannot** guarantee functionality outside of this version. We have tested the software on Windows 10, Windows 11, Ubuntu 24.04 LTS (with MATLAB 2024a), and macOS Catalina (version 10.15). Please note that MathWorks is aware of a text field entry bug on certain Linux distributions, and the solution can be found in a [bug report](https://www.mathworks.com/support/bugreports/1797911?status=SUCCESS) which suggests that the user "Change the window focus mode to "click" instead of "mouse" in the settings". A MathWorks account will be needed to access the report and is linked in the [second issue](https://github.com/waramos/SegmentationGUI/issues/2) raised on this repository.

1. `Software` Folder Use case:
 * Run the `ROISegmentationGUI.mlapp` file.


2. `CompiledSoftware` Folder Use case:
 * Run the `ROISegmentationGUI.p` file.


## Compatible File Formats
1. MATLAB Data (2-5D arrays) - `.mat`

2. Image Volumes - `.tif`/`.tiff`

3. 2D Images - `.jpg`/`.jpeg`, `.png`, `.jfif`, `.tif`/`.tiff`

4. Videos - `.avi`, `.mp4`, `.mpg`/`.mpeg`

5. OME Bio-Formats - we have tested `.czi` (Zeiss), `.lif` (Leica), and `.nd2` (Nikon) formats most extensively and we cannot promise other formats but users can refer to the OME Bio-Formats [supported formats page](https://bio-formats.readthedocs.io/en/v7.3.0/supported-formats.html) for additional information as some formats as more easily readable by their package.

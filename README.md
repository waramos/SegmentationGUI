# A Graphical User Interface (GUI) for diSPIM Data Image Segmentation and More

[ Under Construction - users should be wary that some bugs may still be present as code is being further developed] 

## Introduction
Image segmentation is utilized in many areas of biological research for identifying specific image regions, extracting features, and quantifying signals in microscopy images. Furthermore, automated segmentation approaches can be utilized to reduce the size of data sets by cropping out the regions of interest (ROIs) for subsequent image processing and are especially relevant when handling large datasets, as is common in many light sheet modalities. Here we describe a modular graphical user interface developed in MATLAB which enables the user to navigate and visualize multidimensional data, apply various preprocessing options, and perform segmentation with only 3 adjustable parameters. Preprocessed data is segmented using traditional parametric methods, which can be further refined by post processing options, including active contours and manual adjustments. Resulting datasets from the segmentation can be used to train a deep neural network to perform semantic segmentation on regions for various needs. 

To get additional information about this project and our work, please refer to this [MathWorks News and Stories article](https://www.mathworks.com/company/mathworks-stories/image-processing-and-ai-based-lightsheet-microscopy-tool-provide-data-insight.html).


## GUI
A screenshot of the GUI upon launch shows a cutaway view of a segmented *Parhyale hawaiensis* embryo with a DAPI stain imaged on a diSPIM system.

![GUI](https://github.com/waramos/SegmentationGUI/blob/main/md_images/GUI_launch.png)


### Use
Here, we primarily focus on diSPIM data and show applications of our software to this imaging modality. We prepared a training dataset by manually segmenting  for a 4D volumetric timeseries of a butterfly ovary imaged on a diSPIM system in order to then train a deep network, DeepLabV3+ with Resnet18. This network was then used to process the 

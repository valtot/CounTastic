[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.14761357.svg)](https://doi.org/10.5281/zenodo.14761357)

# CounTastic: a MATLAB-based software for cell counting

CounTastic is a MATLAB-based user interface supporting quantitative analysis of microscopy image data. This tool allows to manually count cells, improve the results of automated counting algorithms, or label new data for the training of supervised machine learning algorithms. Additionally, it includes basic computer vision tools for the automatic localization of circular objects which performs well for typical use cases (e.g. counting of c-fos+ nuclei, microglial cells, etc.). 

This tool was first developed to support image analysis in this [publication](https://www.cell.com/cell-reports/pdf/S2211-1247(23)00799-4.pdf).

Simple computer vision techniques can address the task of cell counting for staining methods that target objects with low morphological variability. For highly heterogeneous objects, more advanced methods such as deep learning models are available. We recommend a pipeline specifically designed for biological objects ([code](https://github.com/ciampluca/counting_perineuronal_nets), [paper](https://www.sciencedirect.com/science/article/pii/S1361841522001475)). The publication comes with pre-trained models for perineuronal nets and parvalbumin-expressing neurons. Alternatively, new custom models using this GUI.

To use the GUI run the `counTastic` in the command window or the `launchCounter.m` script. This will open an interactive figure and a control panel.

## The GUI

![image](https://user-images.githubusercontent.com/64209814/221218319-484c821b-b806-47f7-a61e-c9c318d3252d.png)


The main figure is represented by the GUI on which users can perform counting. In this figure, the experimental image can be loaded using the control panel (see below). The GUI allows two modes: explore and count. In the explore modality, the user can navigate the image, zooming in areas of interest to count more easily. In the count modality, movements of the field of view are blocked and cells can be counted by left-clicking on the image (this will add a red marker) or removed by right-clicking in the proximity of a cell. Switching between the two modalities can be done by pressing the spacebar. The T keyboard shortcut allows you to toggle the red markers and visually inspect the image.

## The control panel

The control panel contains the commands to interact with the GUI.
![image](https://user-images.githubusercontent.com/64209814/221220327-be93e9f5-61ab-4f0a-95c1-df1b4664bf65.png)

### Load the image


The Load image button allows the selection of the experimental image. Note that this code only supports counting on grayscale images, so if you choose an RGB image it will be converted to grayscale. The file formats supported are the same as MATLAB built-in `imread` function. Image brightness can be adjusted by the dedicated bottom panel.

### Managing counts


The `Cell Count` panel contains the buttons to manage the results of cell counts. If you have performed the count manually, you can just save the positions of your red markers in a CSV file by pushing the Save Cell Count to CSV button (a window will open to allow you to choose the saving path).

If you already have a CSV file containing the output of an automated counting procedure, you can load it using the  Load from CSV button. Note that for a proper upload, this file must contain two columns with headers X and Y, respectively.

### Automatic cell count


The `Auto Count Cells` button proposes a preliminary automated count by using functions published and accurately described in [this preprint](https://www.biorxiv.org/content/10.1101/781880v1) (check out also the [source code](https://github.com/cicconet/RiffleShuffle)). This count can be refined manually.

Automated count requires setting some parameters, approximating the cell size, the brightness, and the roundness of the cells. The cell size can be also estimated by pressing the measure button. This will open a new GUI where users can compute the cell size parameter by drawing a rectangle around a few cells. After measuring the dimension of a few example cells, close the measurement GUI and write the estimated dimension in the dedicated field. Then press the `Auto Count Cells` button.

### Selecting a ROI


Suppose you are interested only in a portion of the image (e.g. a specific anatomic area). In that case, you can draw an ROI on the image and compute a mask specifying which part of the image is relevant for your analysis. You can draw a rotatable and resizable rectangular ROI by pressing R, and convert it into a mask with the Enter key. 

You may also want to save the ROI to reuse the same area on multiple images and reload it on a different counting session with the `Save ROI` and `Load ROI` buttons. If you load an ROI, however, this will not be editable but can be rotated and translated. ROIs are saved as `.mat` files.

You can also upload a mask you saved in a previous session (this is the typical case of counting on multiple imaging channels) using the `Load Mask` button. Masks are saved as binary PNG images and used for the analysis. In addition a `.json` file is saved with additional information useful if you do not want to write new code and need to retrieve the size of area of interest identified by the mask (i.e. number of white pixels). This file is also required for the upload of a new mask.

## Contributions and citation

Valentino Totaro and Leonardo Lupori equally contributed to the developement of the code. Tommaso Pizzorusso supervised the project and provided computational resources.

Please cite this tool as 
```
@misc{PizzorussoLabCellCounter,
  author    = {Totaro, V. and Lupori, L. and Pizzorusso, T.},
  title     = {CounTastic: a MATLAB-based GUI for semi-automated cell counting}
  version   = {1.0},
  publisher = {Zenodo},
  month     = january,
  year      = 2024,
  doi       = {10.5281/zenodo.14761357},
  url       = {https://zenodo.org/records/14761357}
}
```
As source publication cite:
```
@article{lupori_comprehensive_2023,
    title = {A comprehensive atlas of perineuronal net distribution and colocalization with parvalbumin in the adult mouse brain},
    volume = {42},
    copyright = {All rights reserved},
    issn = {2211-1247},
    url = {https://www.cell.com/cell-reports/abstract/S2211-1247(23)00799-4},
    doi = {10.1016/j.celrep.2023.112788},
    language = {English},
    number = {7},
    urldate = {2024-03-03},
    journal = {Cell Reports},
    author = {Lupori, Leonardo and Totaro, Valentino and Cornuti, Sara and Ciampi, Luca and Carrara, Fabio and Grilli, Edda and Viglione, Aurelia and Tozzi, Francesca and Putignano, Elena and Mazziotti, Raffaele and Amato, Giuseppe and Gennaro, Claudio and Tognini, Paola and Pizzorusso, Tommaso},
    month = jul,
    year = {2023},
    pmid = {37436896}, 
    note = {Publisher: Elsevier}, 
    keywords = {inhibition, plasticity, extracellular matrix, basket cell, CP: Neuroscience, lectican, neural circuit},
    }
```
Computer vision tools for cell detection included in this application are licensed code and part of the following preprint to which they should be credited:
```
@article {Cicconet781880,
        author = {Cicconet, Marcelo and Hochbaum, Daniel R.}, 
        title = {A Supervised, Symmetry-Driven, GUI Toolkit for Mouse Brain Stack Registration and Plane Assignment},
        elocation-id = {781880},
        year = {2019},
        doi = {10.1101/781880},
        Publisher = {Cold Spring Harbor Laboratory},
        URL = {https://www.biorxiv.org/content/early/2019/09/25/781880},
        eprint = {https://www.biorxiv.org/content/early/2019/09/25/781880.full.pdf},
        journal = {bioRxiv}
}
```
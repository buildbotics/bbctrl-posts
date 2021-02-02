BobCAD requires the machine definition file and the post-processor file together in order to output the correct code.

There are two ways to install post-processor and machine definition.

1- Manual installation
You need to upload the machine definition folder and the post-processor file on the Git site. The attached zip file contains both machine and the post-processor.
Here are the manual installation instructions:

a) Make sure BobCAD-CAM is closed

b) Unzip the attached folder
c) Move the Post Processor file "Buildbotics_OEM_3x_Mill.BCPst" into the default Post Processor folder location for desired BobCAD version. For example, if you are installing the post-processor for BobCAD-CAM V33, the default Post Processor folder location is as follow:
C:\BobCAD-CAM Data\BobCAD-CAM V33\Posts\Mill

d) Move the machine definition folder "Buildbotics_OEM_3x_Mill" into the default MachSim folder location for desired BobCAD version. For example, if you are installing the machine definition for BobCAD-CAM V33, the default MachSim folder location is as follow:
C:\BobCAD-CAM Data\BobCAD-CAM V33\MachSim

e) Once these files are transferred into the respective folders, Open the BobCAD to test the Post Processor output and update the machining results to ensure the functionality of the Post.


2) Using Installer file
I also have included a download link for the post-processor installer .exe file. With the installer, there is no manual installation. You can upload the installer on the GitHub site to make the post-processor installation easier for your customer.

https://bobcad.awsapps.com/workdocs/index.html#/share/document/0f89403d950a66a2327d16fce693785055212dea7af6431e4baf208641d769a1

Here are the instructions for using the installer:

a) Download the installer

b) Close BobCAD if it's open

c) Run the installer

d) Select the desired BoBCAD version

e) Complete the installation process

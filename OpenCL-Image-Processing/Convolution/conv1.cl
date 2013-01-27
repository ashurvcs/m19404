#define DATA_TYPE unsigned char
#define TILE_WIDTH 16
#define TILE_HEIGHT 16
#define KERNEL_RADIUS 1
#define TS 25
//#define MASK_WIDTH 3
//#define MASK_HEIGHT 3

//naive 2d convolution
//M is input image,with no of rows and columns given by width and height
//N is the kernel with no of rows and columns given by mask_width and mask_height
//P is the output image which is the same size as input image
__kernel void conv2D_1(__global DATA_TYPE * M,int width,int height,__global DATA_TYPE *N,int widthstep,int mask_height,__global DATA_TYPE * output)
{
//getting the global and local thread id's
const int x=get_global_id(0);
const int y=get_global_id(1);
const int z=get_global_id(2);
int n=MASK_HEIGHT/2;
if(x<width && y <height &&z<3)
{
//performs computation for pixels in the valid range
int value=0; //local variable used  to store convolution sum
for(int i=0;i<MASK_HEIGHT;i++)
{
//loop over the rows of the pixel neighborhood
for(int j=0;j<MASK_WIDTH;j++)
{
//loop over the columns of the pixels neighborhood


    if((y+i-n>=0) && (x+j-n>=0) && ((y+i-n)< height) && ((x+j-n) <width))
    {
        //condition defines pixels lying within the image borders
        value=value+M[(y+i-n)*widthstep+(3*x+3*j-3*n)+z];//*N[(i)*(MASK_WIDTH)+j];
        //reading the data from global input memory and computing the convolution sum over the neighborhood

   }
}
}
//copying the data to global output memory
output[y*widthstep+3*x+z]=value/9;

}
}






//2d convolution using 2D local memory loads
__kernel void conv2D_2( __constant DATA_TYPE * M,const int width,const int height,__constant DATA_TYPE *N,const int widthstep,const int mask_height, __global DATA_TYPE * output)
{

const int x=get_global_id(0);
const int y=get_global_id(1);
const int z=get_global_id(2);
const int lx=get_local_id(0);
const int ly=get_local_id(1);
const int bx=get_group_id(0);
const int by=get_group_id(1);
const int ls=get_local_size(0);


__local DATA_TYPE Nl[TS][TS];

const signed int n=MASK_WIDTH/2;

const signed int left=((bx)*ls-n+lx);
const signed int top=((by)*ls-n+ly);
const signed int right=((bx)*ls+n+lx);
const signed int bottom=((by)*ls+n+ly);



const signed int left_index=min(max((x-n),0),width);
const signed int top_index=min(max((y-n),0),height);

const signed int idx=top_index*widthstep+3*(left_index)+z;
const signed int cidx=(y)*widthstep+3*(x)+z;

int value=0;

if(x<width && y <height && z<3)
{

//left border pixels
if(lx < n && ly >=n )	
{

   if(left<0)
   Nl[lx][ly+n]=0;
   else
   Nl[lx][ly+n]=M[idx];

}
//bottom border pixels
if(lx<ls-n && ly >=ls-n)  
{
    if(bottom>=height)
    Nl[lx+n][ly+n+n]=0;
    else
    Nl[lx+n][ly+n+n]=M[idx];

}

//top border pixels
if(lx>=n && ly <n )
{
    if(top<0)
    Nl[lx+n][ly]=0;
    else
    Nl[lx+n][ly]=M[idx];
}

//right border pixels
if(lx >=ls-n && ly <ls-n )	//0,15
{
   if(right>=width)
   Nl[lx+n+n][ly+n]=0;
   else
   Nl[lx+n+n][ly+n]=M[idx];


}

///bottom left
if(lx <n && ly >=ls-n )
{
        if(left<0)
        Nl[lx][ly+n]=0;
        else
        Nl[lx][ly+n]=M[idx];

        if(bottom>=height)
        Nl[lx+n][ly+n+n]=0;
        else
        Nl[lx+n][ly+n+n]=M[idx];

        if(left<0 || bottom>=height)
        Nl[lx][ly+n+n]=0;
        else
        Nl[lx][ly+n+n]=M[idx];
}


//top left
if(lx < n && ly <n )
{

	
        if(left<0)
        Nl[lx][ly+n]=0;
        else
        Nl[lx][ly+n]=M[idx];

        if(top<0)
        Nl[lx+n][ly]=0;
        else
        Nl[lx+n][ly]=M[idx];

        if(left<0 || top <0)
        Nl[lx][ly]=0;
        else
        Nl[lx][ly]=M[idx];

}

//top right
if(lx >= ls-n && ly <n )
{

        if(right>=width)
        Nl[lx+n+n][ly+n]=0;
        else
        Nl[lx+n+n][ly+n]=M[idx];

        if(top<0)
        Nl[lx+n][ly]=0;
        else
        Nl[lx+n][ly]=M[idx];

        if(right>=width || top <0)
        Nl[lx+n+n][ly]=0;
        else
        Nl[lx+n+n][ly]=M[idx];

}


///bottom right
if(lx >= ls-n && ly >=ls-n )
{
        if(right>=width)
        Nl[lx+n+n][ly+n]=0;
        else
        Nl[lx+n+n][ly+n]=M[idx];

        if(bottom>=height)
        Nl[lx+n][ly+n+n]=0;
        else
        Nl[lx+n][ly+n+n]=M[idx];

        if(right>=width||bottom>=height)
        Nl[lx+n+n][ly+n+n]=0;
        else
        Nl[lx+n+n][ly+n+n]=M[idx];
}



Nl[n+lx][n+ly]=M[cidx];
}

barrier(CLK_LOCAL_MEM_FENCE);

if(x<width && y <height &&z<3)
{

#ifdef UNROLL1
#pragma unroll 10
for(int i=0;i<MASK_HEIGHT;i++)
{
for(int j=0;j<MASK_WIDTH;j++)
{
	value=value+Nl[j+lx][i+ly];//*N[i*MASK_WIDTH+j];

}
}
#else
//
	value=value+Nl[0+lx][0+ly]*N[0*MASK_WIDTH+0];
	value=value+Nl[1+lx][0+ly]*N[0*MASK_WIDTH+1];
	value=value+Nl[2+lx][0+ly]*N[0*MASK_WIDTH+2];
	value=value+Nl[0+lx][1+ly]*N[1*MASK_WIDTH+0];
	value=value+Nl[1+lx][1+ly]*N[1*MASK_WIDTH+1];
	value=value+Nl[2+lx][1+ly]*N[1*MASK_WIDTH+2];
	value=value+Nl[0+lx][2+ly]*N[2*MASK_WIDTH+0];
	value=value+Nl[1+lx][2+ly]*N[2*MASK_WIDTH+1];
	value=value+Nl[2+lx][2+ly]*N[2*MASK_WIDTH+2];
#endif



output[y*widthstep+3*x+z]=value/(MASK_WIDTH*MASK_HEIGHT);

}
}























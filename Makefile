NOTHREAD = 0 # set to 1 to disable threads

SOURCE = ./faster-rnnlm
CC = g++
CFLAGS = -Wall -march=native -funroll-loops -g -D__STDC_FORMAT_MACROS
CFLAGS += -DEIGEN_DONT_PARALLELIZE # for Eigen
CFLAGS += -I./
LDFLAGS = -lm -lstdc++
ifeq ($(NOTHREAD), 1)
	CFLAGS += -DNOTHREAD
else
	CFLAGS += -pthread
endif

NVCC_RESULT := $(shell which nvcc 2> /dev/null)
NVCC_TEST := $(notdir $(NVCC_RESULT))
ifeq ($(NVCC_TEST), nvcc)
	LDFLAGS += -L/usr/local/cuda/lib64 -lcuda -lcudart -lcublas
else
	CFLAGS += -DNOCUDA
endif

UNAME := $(shell uname)
ifeq ($(UNAME), Darwin)
	CFLAGS += -DNORT
else
	LDFLAGS += -lrt
endif

LAYER_OBJ_FILES = simple_layer.o gru_layer.o scrn_layer.o layer_stack.o interface.o
OBJ_FILES = hierarchical_softmax.o nce.o words.o maxent.o nnet.o $(LAYER_OBJ_FILES)
ifeq ($(NVCC_TEST), nvcc)
	OBJ_FILES += cuda_softmax.o
endif

all: rnnlm

rnnlm : rnnlm.o $(OBJ_FILES)
	$(CC) $^ -o $@ $(CFLAGS) $(LDFLAGS)

hierarchical_softmax.o : $(SOURCE)/hierarchical_softmax.cc $(SOURCE)/hierarchical_softmax.h $(SOURCE)/maxent.h $(SOURCE)/settings.h $(SOURCE)/util.h
	$(CC) $< -c -o $@ $(CFLAGS)

words.o : $(SOURCE)/words.cc $(SOURCE)/words.h $(SOURCE)/settings.h
	$(CC) $< -c -o $@ $(CFLAGS)

rnnlm.o : $(SOURCE)/rnnlm.cc $(SOURCE)/maxent.h $(SOURCE)/nnet.h $(SOURCE)/nce.h $(SOURCE)/settings.h $(SOURCE)/hierarchical_softmax.h $(SOURCE)/words.h $(SOURCE)/layers/interface.h $(SOURCE)/util.h $(SOURCE)/program_options.h
	$(CC) $< -c -o $@ $(CFLAGS)

nce.o : $(SOURCE)/nce.cc $(SOURCE)/nce.h $(SOURCE)/cuda_softmax.h $(SOURCE)/maxent.h $(SOURCE)/layers/interface.h $(SOURCE)/settings.h $(SOURCE)/words.h $(SOURCE)/util.h
	$(CC) $< -c -o $@ $(CFLAGS)

maxent.o : $(SOURCE)/maxent.cc $(SOURCE)/maxent.h $(SOURCE)/util.h $(SOURCE)/settings.h
	$(CC) $< -c -o $@ $(CFLAGS)

nnet.o : $(SOURCE)/nnet.cc $(SOURCE)/nnet.h $(SOURCE)/maxent.h $(SOURCE)/settings.h $(SOURCE)/hierarchical_softmax.h $(SOURCE)/words.h $(SOURCE)/layers/interface.h $(SOURCE)/util.h
	$(CC) $< -c -o $@ $(CFLAGS)

cuda_softmax.o : $(SOURCE)/cuda_softmax.cu $(SOURCE)/cuda_softmax.h $(SOURCE)/settings.h
	nvcc $< -c -Xcompiler "$(NVCC_CFLAGS)" -o $@

simple_layer.o : $(SOURCE)/layers/simple_layer.cc $(SOURCE)/layers/simple_layer.h $(SOURCE)/layers/interface.h $(SOURCE)/layers/activation_functions.h $(SOURCE)/layers/util.h
	$(CC) $< -c -o $@ $(CFLAGS)

scrn_layer.o : $(SOURCE)/layers/scrn_layer.cc $(SOURCE)/layers/scrn_layer.h $(SOURCE)/layers/interface.h $(SOURCE)/layers/util.h $(SOURCE)/layers/activation_functions.h $(SOURCE)/settings.h $(SOURCE)/util.h
	$(CC) $< -c -o $@ $(CFLAGS)

gru_layer.o : $(SOURCE)/layers/gru_layer.cc $(SOURCE)/layers/gru_layer.h $(SOURCE)/layers/interface.h $(SOURCE)/layers/util.h $(SOURCE)/layers/activation_functions.h $(SOURCE)/settings.h $(SOURCE)/util.h
	$(CC) $< -c -o $@ $(CFLAGS)

layer_stack.o : $(SOURCE)/layers/layer_stack.cc $(SOURCE)/layers/layer_stack.h $(SOURCE)/layers/interface.h $(SOURCE)/layers/util.h $(SOURCE)/settings.h $(SOURCE)/util.h
	$(CC) $< -c -o $@ $(CFLAGS)

interface.o : $(SOURCE)/layers/interface.cc $(SOURCE)/layers/interface.h $(SOURCE)/layers/util.h $(SOURCE)/settings.h $(SOURCE)/util.h $(SOURCE)/layers/simple_layer.h $(SOURCE)/layers/scrn_layer.h $(SOURCE)/layers/gru_layer.h $(SOURCE)/layers/layer_stack.h
	$(CC) $< -c -o $@ $(CFLAGS)

test_gradients/test_gradients : test_gradients/test_gradients.cc $(OBJ_FILES)
	$(CC) $^ -o $@ -std=gnu++0x $(CFLAGS) $(LDFLAGS)

clean:
	rm -f rnnlm rnnlm.o $(OBJ_FILES)

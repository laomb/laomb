#include <kheap.h>
#include <sys/mm/pmm.h>
#include <string.h>
#include <io.h>
#include <kprintf>

/**  Durand's Amazing Super Duper Memory functions.  */

#define ALIGNMENT	16ul//4ul				///< This is the byte alignment that memory must be allocated on. IMPORTANT for GTK and other stuff.

#define ALIGN_TYPE		char ///unsigned char[16] /// unsigned short
#define ALIGN_INFO		sizeof(ALIGN_TYPE)*16	///< Alignment information is stored right before the pointer. This is the number of bytes of information stored there.

#define USE_CASE1
#define USE_CASE2
#define USE_CASE3
#define USE_CASE4
#define USE_CASE5

//TODO: Mutexes?
extern int liballoc_lock() {
	cli();
	return 0;
}
extern int liballoc_unlock()
{
	sti();
	return 0;
}
extern uintptr_t higher_half_base;

extern void* liballoc_alloc(size_t pages)
{
	void* ptr = (pmm_alloc_pages(pages) + higher_half_base);
	return ptr;
}
extern int liballoc_free(void* ptr,size_t pages)
{
	pmm_free_pages((ptr - higher_half_base), pages);
	return 0;
}


/** This macro will conveniently align our pointer upwards */
#define ALIGN( ptr )													\
		if ( ALIGNMENT > 1 )											\
		{																\
			uintptr_t diff;												\
			ptr = (void*)((uintptr_t)ptr + ALIGN_INFO);					\
			diff = (uintptr_t)ptr & (ALIGNMENT-1);						\
			if ( diff != 0 )											\
			{															\
				diff = ALIGNMENT - diff;								\
				ptr = (void*)((uintptr_t)ptr + diff);					\
			}															\
			*((ALIGN_TYPE*)((uintptr_t)ptr - ALIGN_INFO)) = 			\
				diff + ALIGN_INFO;										\
		}															


#define UNALIGN( ptr )													\
		if ( ALIGNMENT > 1 )											\
		{																\
			uintptr_t diff = *((ALIGN_TYPE*)((uintptr_t)ptr - ALIGN_INFO));	\
			if ( diff < (ALIGNMENT + ALIGN_INFO) )						\
			{															\
				ptr = (void*)((uintptr_t)ptr - diff);					\
			}															\
		}
				


#define LIBALLOC_MAGIC	0xc001c0de
#define LIBALLOC_DEAD	0xdeaddead

/** A structure found at the top of all system allocated 
 * memory blocks. It details the usage of the memory block.
 */
struct liballoc_major
{
	struct liballoc_major *prev;		///< Linked list information.
	struct liballoc_major *next;		///< Linked list information.
	unsigned int pages;					///< The number of pages in the block.
	unsigned int size;					///< The number of pages in the block.
	unsigned int usage;					///< The number of bytes used in the block.
	struct liballoc_minor *first;		///< A pointer to the first allocated memory in the block.	
};


/** This is a structure found at the beginning of all
 * sections in a major block which were allocated by a
 * malloc, calloc, realloc call.
 */
struct	liballoc_minor
{
	struct liballoc_minor *prev;		///< Linked list information.
	struct liballoc_minor *next;		///< Linked list information.
	struct liballoc_major *block;		///< The owning block. A pointer to the major structure.
	unsigned int magic;					///< A magic number to idenfity correctness.
	unsigned int size; 					///< The size of the memory allocated. Could be 1 byte or more.
	unsigned int req_size;				///< The size of memory requested.
};


static struct liballoc_major *l_memRoot = nullptr;	///< The root memory block acquired from the system.
static struct liballoc_major *l_bestBet = nullptr; ///< The major with the most free memory.

static unsigned int l_pageSize  = 4096;			///< The size of an individual page. Set up in liballoc_init.
static unsigned int l_pageCount = 16;			///< The number of pages to request per chunk. Set up in liballoc_init.
static unsigned long long l_allocated = 0;		///< Running total of allocated memory.
static unsigned long long l_inuse	 = 0;		///< Running total of used memory.


static long long l_warningCount = 0;		///< Number of warnings encountered
static long long l_errorCount = 0;			///< Number of actual errors
static long long l_possibleOverruns = 0;	///< Number of possible overruns

// ***************************************************************

static struct liballoc_major *allocate_new_page( unsigned int size )
{
	unsigned int st;
	struct liballoc_major *maj;

		st  = size + sizeof(struct liballoc_major);
		st += sizeof(struct liballoc_minor);

		if ( (st % l_pageSize) == 0 )
			st  = st / (l_pageSize);
		else
			st  = st / (l_pageSize) + 1;

		
		if ( st < l_pageCount ) st = l_pageCount;
		
		maj = (struct liballoc_major*)liballoc_alloc( st );

		if ( maj == nullptr ) 
		{
			l_warningCount += 1;
			return nullptr;	// uh oh, we ran out of memory.
		}
		
		maj->prev 	= nullptr;
		maj->next 	= nullptr;
		maj->pages 	= st;
		maj->size 	= st * l_pageSize;
		maj->usage 	= sizeof(struct liballoc_major);
		maj->first 	= nullptr;

		l_allocated += maj->size;
		
      return maj;
}

void *PREFIX(malloc)(size_t req_size)
{
	int startedBet = 0;
	unsigned long long bestSize = 0;
	void *p = nullptr;
	uintptr_t diff;
	struct liballoc_major *maj;
	struct liballoc_minor *min;
	struct liballoc_minor *new_min;
	unsigned long size = req_size;

	if ( ALIGNMENT > 1 )
	{
		size += ALIGNMENT + ALIGN_INFO;
	}
	
	liballoc_lock();

	if ( size == 0 )
	{
		l_warningCount += 1;
		liballoc_unlock();
		return PREFIX(malloc)(1);
	}
	

	if ( l_memRoot == nullptr )
	{
		l_memRoot = allocate_new_page( size );
		if ( l_memRoot == nullptr )
		{
		  liballoc_unlock();
		  return nullptr;
		}
	}

	maj = l_memRoot;
	startedBet = 0;
	
	if ( l_bestBet != nullptr )
	{
		bestSize = l_bestBet->size - l_bestBet->usage;

		if ( bestSize > (size + sizeof(struct liballoc_minor)))
		{
			maj = l_bestBet;
			startedBet = 1;
		}
	}
	
	while ( maj != nullptr )
	{
		diff  = maj->size - maj->usage;	
										// free memory in the block

		if ( bestSize < diff )
		{
			// Hmm.. this one has more memory then our bestBet. Remember!
			l_bestBet = maj;
			bestSize = diff;
		}
		
		
#ifdef USE_CASE1
			
		// CASE 1:  There is not enough space in this major block.
		if ( diff < (size + sizeof( struct liballoc_minor )) )
		{
			#ifdef DEBUG
			printf( "CASE 1: Insufficient space in block %x\n", maj);
			FLUSH();
			#endif
				
				// Another major block next to this one?
			if ( maj->next != nullptr ) 
			{
				maj = maj->next;		// Hop to that one.
				continue;
			}

			if ( startedBet == 1 )		// If we started at the best bet,
			{							// let's start all over again.
				maj = l_memRoot;
				startedBet = 0;
				continue;
			}

			// Create a new major block next to this one and...
			maj->next = allocate_new_page( size );	// next one will be okay.
			if ( maj->next == nullptr ) break;			// no more memory.
			maj->next->prev = maj;
			maj = maj->next;

			// .. fall through to CASE 2 ..
		}

#endif

#ifdef USE_CASE2
		
		// CASE 2: It's a brand new block.
		if ( maj->first == nullptr )
		{
			maj->first = (struct liballoc_minor*)((uintptr_t)maj + sizeof(struct liballoc_major) );

			
			maj->first->magic 		= LIBALLOC_MAGIC;
			maj->first->prev 		= nullptr;
			maj->first->next 		= nullptr;
			maj->first->block 		= maj;
			maj->first->size 		= size;
			maj->first->req_size 	= req_size;
			maj->usage 	+= size + sizeof( struct liballoc_minor );


			l_inuse += size;
			
			
			p = (void*)((uintptr_t)(maj->first) + sizeof( struct liballoc_minor ));

			ALIGN( p );
			
			#ifdef DEBUG
			printf( "CASE 2: returning %x\n", p); 
			FLUSH();
			#endif
			liballoc_unlock();		// release the lock
			return p;
		}

#endif
				
#ifdef USE_CASE3

		// CASE 3: Block in use and enough space at the start of the block.
		diff =  (uintptr_t)(maj->first);
		diff -= (uintptr_t)maj;
		diff -= sizeof(struct liballoc_major);

		if ( diff >= (size + sizeof(struct liballoc_minor)) )
		{
			// Yes, space in front. Squeeze in.
			maj->first->prev = (struct liballoc_minor*)((uintptr_t)maj + sizeof(struct liballoc_major) );
			maj->first->prev->next = maj->first;
			maj->first = maj->first->prev;
				
			maj->first->magic 	= LIBALLOC_MAGIC;
			maj->first->prev 	= nullptr;
			maj->first->block 	= maj;
			maj->first->size 	= size;
			maj->first->req_size 	= req_size;
			maj->usage 			+= size + sizeof( struct liballoc_minor );

			l_inuse += size;

			p = (void*)((uintptr_t)(maj->first) + sizeof( struct liballoc_minor ));
			ALIGN( p );

			#ifdef DEBUG
			printf( "CASE 3: returning %x\n", p); 
			FLUSH();
			#endif
			liballoc_unlock();		// release the lock
			return p;
		}
		
#endif


#ifdef USE_CASE4

		// CASE 4: There is enough space in this block. But is it contiguous?
		min = maj->first;
		
			// Looping within the block now...
		while ( min != nullptr )
		{
				// CASE 4.1: End of minors in a block. Space from last and end?
				if ( min->next == nullptr )
				{
					// the rest of this block is free...  is it big enough?
					diff = (uintptr_t)(maj) + maj->size;
					diff -= (uintptr_t)min;
					diff -= sizeof( struct liballoc_minor );
					diff -= min->size; 
						// minus already existing usage..

					if ( diff >= (size + sizeof( struct liballoc_minor )) )
					{
						// yay....
						min->next = (struct liballoc_minor*)((uintptr_t)min + sizeof( struct liballoc_minor ) + min->size);
						min->next->prev = min;
						min = min->next;
						min->next = nullptr;
						min->magic = LIBALLOC_MAGIC;
						min->block = maj;
						min->size = size;
						min->req_size = req_size;
						maj->usage += size + sizeof( struct liballoc_minor );

						l_inuse += size;
						
						p = (void*)((uintptr_t)min + sizeof( struct liballoc_minor ));
						ALIGN( p );

						#ifdef DEBUG
						printf( "CASE 4.1: returning %x\n", p); 
						FLUSH();
						#endif
						liballoc_unlock();		// release the lock
						return p;
					}
				}



				// CASE 4.2: Is there space between two minors?
				if ( min->next != nullptr )
				{
					// is the difference between here and next big enough?
					diff  = (uintptr_t)(min->next);
					diff -= (uintptr_t)min;
					diff -= sizeof( struct liballoc_minor );
					diff -= min->size;
										// minus our existing usage.

					if ( diff >= (size + sizeof( struct liballoc_minor )) )
					{
						// yay......
						new_min = (struct liballoc_minor*)((uintptr_t)min + sizeof( struct liballoc_minor ) + min->size);

						new_min->magic = LIBALLOC_MAGIC;
						new_min->next = min->next;
						new_min->prev = min;
						new_min->size = size;
						new_min->req_size = req_size;
						new_min->block = maj;
						min->next->prev = new_min;
						min->next = new_min;
						maj->usage += size + sizeof( struct liballoc_minor );
						
						l_inuse += size;
						
						p = (void*)((uintptr_t)new_min + sizeof( struct liballoc_minor ));
						ALIGN( p );


						#ifdef DEBUG
						printf( "CASE 4.2: returning %x\n", p); 
						FLUSH();
						#endif
						
						liballoc_unlock();		// release the lock
						return p;
					}
				}	// min->next != nullptr

				min = min->next;
		} // while min != nullptr ...


#endif

#ifdef USE_CASE5

		// CASE 5: Block full! Ensure next block and loop.
		if ( maj->next == nullptr ) 
		{
			#ifdef DEBUG
			printf( "CASE 5: block full\n");
			FLUSH();
			#endif

			if ( startedBet == 1 )
			{
				maj = l_memRoot;
				startedBet = 0;
				continue;
			}
				
			// we've run out. we need more...
			maj->next = allocate_new_page( size );		// next one guaranteed to be okay
			if ( maj->next == nullptr ) break;			//  uh oh,  no more memory.....
			maj->next->prev = maj;

		}

#endif

		maj = maj->next;
	} // while (maj != nullptr)


	
	liballoc_unlock();		// release the lock

	#ifdef DEBUG
	printf( "All cases exhausted. No memory available.\n");
	FLUSH();
	#endif
	#if defined DEBUG || defined INFO
	printf( "liballoc: WARNING: PREFIX(malloc)( %i ) returning nullptr.\n", size);
	liballoc_dump();
	FLUSH();
	#endif
	return nullptr;
}









void PREFIX(free)(void *ptr)
{
	struct liballoc_minor *min;
	struct liballoc_major *maj;

	if ( ptr == nullptr ) 
	{
		l_warningCount += 1;
		#if defined DEBUG || defined INFO
		printf( "liballoc: WARNING: PREFIX(free)( nullptr ) called from %x\n",
							__builtin_return_address(0) );
		FLUSH();
		#endif
		return;
	}

	UNALIGN( ptr );

	liballoc_lock();		// lockit


	min = (struct liballoc_minor*)((uintptr_t)ptr - sizeof( struct liballoc_minor ));

	
	if ( min->magic != LIBALLOC_MAGIC ) 
	{
		l_errorCount += 1;

		// Check for overrun errors. For all bytes of LIBALLOC_MAGIC 
		if ( 
			((min->magic & 0xFFFFFF) == (LIBALLOC_MAGIC & 0xFFFFFF)) || 
			((min->magic & 0xFFFF) == (LIBALLOC_MAGIC & 0xFFFF)) || 
			((min->magic & 0xFF) == (LIBALLOC_MAGIC & 0xFF)) 
		   )
		{
			l_possibleOverruns += 1;
			#if defined DEBUG || defined INFO
			printf( "liballoc: ERROR: Possible 1-3 byte overrun for magic %x != %x\n",
								min->magic,
								LIBALLOC_MAGIC );
			FLUSH();
			#endif
		}
						
						
		if ( min->magic == LIBALLOC_DEAD )
		{
			#if defined DEBUG || defined INFO
			printf( "liballoc: ERROR: multiple PREFIX(free)() attempt on %x from %x.\n", 
									ptr,
									__builtin_return_address(0) );
			FLUSH();
			#endif
		}
		else
		{
			#if defined DEBUG || defined INFO
			printf( "liballoc: ERROR: Bad PREFIX(free)( %x ) called from %x\n",
								ptr,
								__builtin_return_address(0) );
			FLUSH();
			#endif
		}
			
		// being lied to...
		liballoc_unlock();		// release the lock
		return;
	}

	#ifdef DEBUG
	printf( "liballoc: %x PREFIX(free)( %x ): ", 
				__builtin_return_address( 0 ),
				ptr );
	FLUSH();
	#endif
	

		maj = min->block;

		l_inuse -= min->size;

		maj->usage -= (min->size + sizeof( struct liballoc_minor ));
		min->magic  = LIBALLOC_DEAD;		// No mojo.

		if ( min->next != nullptr ) min->next->prev = min->prev;
		if ( min->prev != nullptr ) min->prev->next = min->next;

		if ( min->prev == nullptr ) maj->first = min->next;	
							// Might empty the block. This was the first
							// minor.


	// We need to clean up after the majors now....

	if ( maj->first == nullptr )	// Block completely unused.
	{
		if ( l_memRoot == maj ) l_memRoot = maj->next;
		if ( l_bestBet == maj ) l_bestBet = nullptr;
		if ( maj->prev != nullptr ) maj->prev->next = maj->next;
		if ( maj->next != nullptr ) maj->next->prev = maj->prev;
		l_allocated -= maj->size;

		liballoc_free( maj, maj->pages );
	}
	else
	{
		if ( l_bestBet != nullptr )
		{
			int bestSize = l_bestBet->size  - l_bestBet->usage;
			int majSize = maj->size - maj->usage;

			if ( majSize > bestSize ) l_bestBet = maj;
		}

	}
	

	#ifdef DEBUG
	printf( "OK\n");
	FLUSH();
	#endif
	
	liballoc_unlock();		// release the lock
}





void* PREFIX(calloc)(size_t nobj, size_t size)
{
       int real_size;
       void *p;

       real_size = nobj * size;
       
       p = PREFIX(malloc)( real_size );

       memset( p, 0, real_size );

       return p;
}



void*   PREFIX(realloc)(void *p, size_t size)
{
	void *ptr;
	struct liballoc_minor *min;
	unsigned int real_size;
	
	// Honour the case of size == 0 => free old and return nullptr
	if ( size == 0 )
	{
		PREFIX(free)( p );
		return nullptr;
	}

	// In the case of a nullptr pointer, return a simple malloc.
	if ( p == nullptr ) return PREFIX(malloc)( size );

	// Unalign the pointer if required.
	ptr = p;
	UNALIGN(ptr);

	liballoc_lock();		// lockit

		min = (struct liballoc_minor*)((uintptr_t)ptr - sizeof( struct liballoc_minor ));

		// Ensure it is a valid structure.
		if ( min->magic != LIBALLOC_MAGIC ) 
		{
			l_errorCount += 1;
	
			// Check for overrun errors. For all bytes of LIBALLOC_MAGIC 
			if ( 
				((min->magic & 0xFFFFFF) == (LIBALLOC_MAGIC & 0xFFFFFF)) || 
				((min->magic & 0xFFFF) == (LIBALLOC_MAGIC & 0xFFFF)) || 
				((min->magic & 0xFF) == (LIBALLOC_MAGIC & 0xFF)) 
			   )
			{
				l_possibleOverruns += 1;
				#if defined DEBUG || defined INFO
				printf( "liballoc: ERROR: Possible 1-3 byte overrun for magic %x != %x\n",
									min->magic,
									LIBALLOC_MAGIC );
				FLUSH();
				#endif
			}
							
							
			if ( min->magic == LIBALLOC_DEAD )
			{
				#if defined DEBUG || defined INFO
				printf( "liballoc: ERROR: multiple PREFIX(free)() attempt on %x from %x.\n", 
										ptr,
										__builtin_return_address(0) );
				FLUSH();
				#endif
			}
			else
			{
				#if defined DEBUG || defined INFO
				printf( "liballoc: ERROR: Bad PREFIX(free)( %x ) called from %x\n",
									ptr,
									__builtin_return_address(0) );
				FLUSH();
				#endif
			}
			
			// being lied to...
			liballoc_unlock();		// release the lock
			return nullptr;
		}	
		
		// Definitely a memory block.
		
		real_size = min->req_size;

		if ( real_size >= size ) 
		{
			min->req_size = size;
			liballoc_unlock();
			return p;
		}

	liballoc_unlock();

	// If we got here then we're reallocating to a block bigger than us.
	ptr = PREFIX(malloc)( size );					// We need to allocate new memory
	memcpy( ptr, p, real_size );
	PREFIX(free)( p );

	return ptr;
}
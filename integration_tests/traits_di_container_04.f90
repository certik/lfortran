! The dependency injection container of Sect. 4 of the traits extension
! proposal, Traits-for-Fortran Extensions/traits-di-extension.md, in the
! file layout of the `projected` branch of FortranDIContainer, compiled
! separately: the trait modules in traits_di_container_04_interfaces, the
! other modules in traits_di_container_04_lib, and this main program, the
! file Main.f90 verbatim, followed by checks of this test, marked "test:".
! The generic `register` and `resolve` of the container, the generic
! initializers of `Factory` and the generic factory types are instantiated
! here, from the module files.
! GFortran does not accept this LFortran extension.
program main

   use IClientMod,      only: IClient
   use ILoggerMod,      only: ILogger
   use IPrinterMod,     only: IPrinter
   use IWriterMod,      only: IWriter

   use ContainerMod,    only: Container
   use ClientMod,       only: Client
   use SingleLoggerMod, only: SingleLogger
   use DoubleLoggerMod, only: DoubleLogger
   use PrinterMod,      only: Printer
   use WriterMod,       only: Writer

   implicit none

   !.. locals
   type(Container), allocatable :: cont
   class(IClient),  allocatable :: cobj
   class(ILogger),  allocatable :: lobj   ! test:

   !.. get a (Dependency Injection) Container object
   cont = Container()

   !.. register a concrete type (initializer) with each interface
   call cont%register{IClient}(Client)
   call cont%register{ILogger}(DoubleLogger)
   call cont%register{IPrinter}(Printer)
   call cont%register{IWriter}(Writer)

   !.. recursively resolve the interfaces, starting at the top
   cobj = cont%resolve{IClient}()

   !.. use the constructed Client instance
   call cobj%log()

   ! test: the object graph has the registered types
   select type (cobj)
   type is (Client)
   class default
      error stop 1
   end select
   lobj = cont%resolve{ILogger}()
   select type (lobj)
   type is (DoubleLogger)
   class default
      error stop 2
   end select

   ! test: switching to single logging changes one registration
   call cont%register{ILogger}(SingleLogger)
   lobj = cont%resolve{ILogger}()
   select type (lobj)
   type is (SingleLogger)
   class default
      error stop 3
   end select

   ! test: finalize the container's map, which the end of the program does
   ! not, so that --detect-leaks finds no leaks
   deallocate(cont)

end program main

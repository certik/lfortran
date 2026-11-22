! The trait modules of the dependency injection container of Sect. 4 of the
! traits extension proposal, Traits-for-Fortran
! Extensions/traits-di-extension.md: the files of src/Interfaces of the
! `projected` branch of FortranDIContainer, verbatim, in the order of its
! CMakeLists.txt. Compiled separately from traits_di_container_04_lib and
! the main program traits_di_container_04.
! GFortran does not accept this LFortran extension.

! ---- Interfaces/IPrinterMod.f90
module IPrinterMod

   implicit none
   private

   public :: IPrinter

   abstract interface :: IPrinter
      subroutine printout()
      end subroutine printout
   end interface

end module IPrinterMod

! ---- Interfaces/IWriterMod.f90
module IWriterMod

   implicit none
   private

   public :: IWriter

   abstract interface :: IWriter
      subroutine writeout()
      end subroutine writeout
   end interface

end module IWriterMod

! ---- Interfaces/ILoggerMod.f90
module ILoggerMod

   implicit none
   private

   public :: ILogger

   abstract interface :: ILogger
      subroutine log(self)
         type(itself), pass, intent(in) :: self
      end subroutine log
   end interface

end module ILoggerMod

! ---- Interfaces/IClientMod.f90
module IClientMod

   use ILoggerMod, only: ILogger

   implicit none
   private

   public :: IClient

   abstract interface, extends(ILogger) :: IClient
   end interface

end module IClientMod

! ---- Interfaces/IResolverMod.f90
module IResolverMod

   implicit none

   abstract interface :: IResolver
      function resolve{Trait::P}(self) result(res)
         type(itself), pass, intent(in)  :: self
         class(P),           allocatable :: res
      end function resolve
   end interface

end module IResolverMod

! ---- Interfaces/IFactoryMod.f90
module IFactoryMod

   use IResolverMod, only: IResolver

   implicit none

   abstract interface :: IFactory
      function create(self,c) result(res)
         type(itself), pass, intent(in)  :: self
         class(IResolver),   intent(in)  :: c
         class(*),           allocatable :: res
      end function create
   end interface

end module IFactoryMod

! ---- Interfaces/InterfacesMod.f90
module InterfacesMod

   implicit none

   abstract interface
      function ctor0{U}() result(res)
         type(U) :: res
      end function ctor0

      function ctor1{Trait::T1, U}(a) result(res)
         class(T1), intent(in) :: a
         type(U)               :: res
      end function ctor1

      function ctor2{Trait::T1, Trait::T2, U}(a, b) result(res)
         class(T1), intent(in) :: a
         class(T2), intent(in) :: b
         type(U)               :: res
      end function ctor2
   end interface

end module InterfacesMod
